using AlgebraicAgents, Agents
using Plots
import Random
import StatsBase: sample, Weights

include("agents_sir.jl")

# test pure Agents.jl solution vs AlgebraicAgents.jl wrap

# Agents.jl
Random.seed!(2023)

# use Agents.jl predefined model, in https://juliadynamics.github.io/Agents.jl/stable/models/#Predefined-Models-1
abm_agents, agent_step, _ = sir()

# data to collect
infected(x) = count(i == :I for i in x)
recovered(x) = count(i == :R for i in x)
to_collect = [(:status, f) for f in (infected, recovered, length)]

# AlgebraicAgents.jl
Random.seed!(2023)

# use Agents.jl predefined model, in https://juliadynamics.github.io/Agents.jl/stable/models/#Predefined-Models-1
abm_algebraic, _, _ = sir()

# modify stepping functions
function agent_step!(agent, model)
    @get_model model
    extract_agent(model, agent)
    sir_migrate!(agent, model)
    sir_transmit!(agent, model)
    sir_update!(agent, model)
    return sir_recover_or_die!(agent, model)
end

@testset "Agents.jl and AlgebraicAgents.jl solution are equal" begin
    Random.seed!(1)
    abm_algebraic_wrap = ABMAgent(
        "sir_model", abm_algebraic;
        tspan = (0.0, 10.0), adata = to_collect
    )
    simulate(abm_algebraic_wrap)
    data_algebraic = abm_algebraic_wrap.df_agents

    Random.seed!(1)
    data_agent, _ = run!(abm_agents, 10; adata = to_collect)

    @test abm_algebraic_wrap.t == 10.0
    @test data_algebraic == data_agent
    # test if number of surviving agents equals the number of wrap's "inner" agents
    @test length(inners(abm_algebraic_wrap)) == data_algebraic[end, :length_status]
end

@testset "plotting for ABM wraps" begin
    abm_algebraic_wrap = ABMAgent(
        "sir_model", abm_algebraic;
        tspan = (0.0, 10.0), adata = to_collect
    )
    simulate(abm_algebraic_wrap)

    @test draw(abm_algebraic_wrap) isa Plots.Plot
end

# Exercise the `@get_model` and `@a` macros from within a *stepped* model. These
# macros expand to references that must resolve against the loaded Agents
# extension rather than the `Agents` weakdep symbol inside `AlgebraicAgents`;
# wiring them into `agent_step!` guards against that regression.
function macro_agent_step!(agent, model)
    @get_model model
    extract_agent(model, agent)
    # remove every infected agent via the algebraic `@a` wrapper
    return if agent.status == :I
        @a remove_agent!(agent, model)
    end
end

@testset "`@get_model` and `@a` macros within stepping" begin
    Random.seed!(1)
    space = GraphSpace(Agents.Graphs.complete_graph(4))
    abm_macro = StandardABM(
        PoorSoul, space; agent_step! = macro_agent_step!, model_step! = identity,
        properties = Dict{Symbol, Any}()
    )
    for _ in 1:20
        add_agent!(rand(1:4), abm_macro, 0, :I)
    end

    abm_macro_wrap = ABMAgent("sir_macro_model", abm_macro; tspan = (0.0, 5.0))
    # both macros are evaluated during stepping; this should not error
    @test simulate(abm_macro_wrap) isa AlgebraicAgents.ABMAgent
    # `@a remove_agent!` keeps the algebraic wrap's inners in sync with the ABM and
    # removes the infected agents
    @test length(inners(abm_macro_wrap)) == Agents.nagents(abm_macro_wrap.abm) == 0
end

# `@a add_agent!` spawns a susceptible agent for each infected one, then recovers
# the infected agent so the spawn happens exactly once per original agent.
function add_agent_step!(agent, model)
    @get_model model
    return if agent.status == :I
        new = @a add_agent!(agent.pos, model, 0, :S)
        agent.status = :R
        new
    end
end

@testset "`@a add_agent!` keeps the wrap in sync" begin
    Random.seed!(1)
    space = GraphSpace(Agents.Graphs.complete_graph(4))
    abm_add = StandardABM(
        PoorSoul, space; agent_step! = add_agent_step!, model_step! = identity,
        properties = Dict{Symbol, Any}()
    )
    for _ in 1:5
        add_agent!(rand(1:4), abm_add, 0, :I)
    end

    abm_add_wrap = ABMAgent("add_model", abm_add; tspan = (0.0, 3.0))
    simulate(abm_add_wrap)

    # the five infected agents each spawned one susceptible agent
    @test Agents.nagents(abm_add_wrap.abm) == 10
    # `@a add_agent!` entangled each new agent, so inners track the ABM exactly
    @test length(inners(abm_add_wrap)) == Agents.nagents(abm_add_wrap.abm)
end
