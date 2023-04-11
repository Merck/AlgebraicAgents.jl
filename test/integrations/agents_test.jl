using AlgebraicAgents, Agents
using Plots
import Random
import StatsBase: sample, Weights

# test pure Agents.jl solution vs AlgebraicAgents.jl wrap

# Agents.jl
Random.seed!(2023)

# use Agents.jl predefined model, in https://juliadynamics.github.io/Agents.jl/stable/models/#Predefined-Models-1
abm_agents, agent_step, _ = Agents.Models.sir()

# data to collect
infected(x) = count(i == :I for i in x)
recovered(x) = count(i == :R for i in x)
to_collect = [(:status, f) for f in (infected, recovered, length)]

# AlgebraicAgents.jl
Random.seed!(2023)

# use Agents.jl predefined model, in https://juliadynamics.github.io/Agents.jl/stable/models/#Predefined-Models-1
abm_algebraic, _, _ = Agents.Models.sir()

# modify stepping functions
function agent_step!(agent, model)
    @get_model model
    extract_agent(model, agent)
    migrate!(agent, model)
    transmit!(agent, model)
    update!(agent, model)
    recover_or_die!(agent, model)
end

function migrate!(agent, model)
    pid = agent.pos
    m = sample(model.rng, 1:(model.C), Weights(model.migration_rates[pid, :]))
    if m ≠ pid
        move_agent!(agent, m, model)
    end
end

function transmit!(agent, model)
    agent.status == :S && return
    rate = if agent.days_infected < model.detection_time
        model.β_und[agent.pos]
    else
        model.β_det[agent.pos]
    end

    n = rate * abs(randn(model.rng))
    n <= 0 && return

    for contactID in ids_in_position(agent, model)
        contact = model[contactID]
        if contact.status == :S ||
           (contact.status == :R && rand(model.rng) ≤ model.reinfection_probability)
            contact.status = :I
            n -= 1
            n <= 0 && return
        end
    end
end

update!(agent, model) = agent.status == :I && (agent.days_infected += 1)

function recover_or_die!(agent, model)
    if agent.days_infected ≥ model.infection_period
        if rand(model.rng) ≤ model.death_rate
            @a kill_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end

@testset "Agents.jl and AlgebraicAgents.jl solution are equal" begin
    Random.seed!(1)
    abm_algebraic_wrap = ABMAgent("sir_model", abm_algebraic; agent_step!,
                                  tspan = (0.0, 10.0), adata = to_collect)
    simulate(abm_algebraic_wrap)
    data_algebraic = abm_algebraic_wrap.df_agents

    Random.seed!(1)
    data_agent, _ = run!(abm_agents, agent_step, 10; adata = to_collect)

    @test abm_algebraic_wrap.t == 10.0
    @test data_algebraic == data_agent
    # test if number of surviving agents equals the number of wrap's "inner" agents
    @test length(inners(abm_algebraic_wrap)) == data_algebraic[end, :length_status]
end

@testset "plotting for ABM wraps" begin
    abm_algebraic_wrap = ABMAgent("sir_model", abm_algebraic; agent_step!,
                                  tspan = (0.0, 10.0), adata = to_collect)
    simulate(abm_algebraic_wrap)

    @test draw(abm_algebraic_wrap) isa Plots.Plot
end
