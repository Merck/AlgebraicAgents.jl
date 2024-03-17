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
    sir_recover_or_die!(agent, model)
end

@testset "Agents.jl and AlgebraicAgents.jl solution are equal" begin
    Random.seed!(1)
    abm_algebraic_wrap = ABMAgent("sir_model", abm_algebraic;
        tspan = (0.0, 10.0), adata = to_collect)
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
    abm_algebraic_wrap = ABMAgent("sir_model", abm_algebraic;
        tspan = (0.0, 10.0), adata = to_collect)
    simulate(abm_algebraic_wrap)

    @test draw(abm_algebraic_wrap) isa Plots.Plot
end
