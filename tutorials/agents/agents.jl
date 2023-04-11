# # Agents.jl Integration
#
# We instantiate an agent-based SIR model based on [Agents.jl: SIR model for the spread of COVID-19](https://juliadynamics.github.io/Agents.jl/stable/examples/sir/) make use of a SIR model constructor from an Agents.jl' [SIR model for the spread of COVID-19](https://juliadynamics.github.io/Agents.jl/stable/examples/sir/), and then we simulate the model using AlgebraicAgents.jl
#
# ## SIR Model in Agents.jl
#
# To begin with, we define the Agents.jl model:

## SIR model for the spread of COVID-19
## taken from https://juliadynamics.github.io/Agents.jl/stable/examples/sir/
using AlgebraicAgents
using Agents, Random
using Agents.DataFrames, Agents.Graphs
using Distributions: Poisson, DiscreteNonParametric
using DrWatson: @dict
using Plots

@agent PoorSoul GraphAgent begin
    days_infected::Int  ## number of days since is infected
    status::Symbol  ## 1: S, 2: I, 3:R
end

# Let's provide the constructors:

function model_initiation(;
                          Ns,
                          migration_rates,
                          β_und,
                          β_det,
                          infection_period = 30,
                          reinfection_probability = 0.05,
                          detection_time = 14,
                          death_rate = 0.02,
                          Is = [zeros(Int, length(Ns) - 1)..., 1],
                          seed = 0)
    rng = MersenneTwister(seed)
    @assert length(Ns)==
            length(Is)==
            length(β_und)==
            length(β_det)==
            size(migration_rates, 1) "length of Ns, Is, and B, and number of rows/columns in migration_rates should be the same "
    @assert size(migration_rates, 1)==size(migration_rates, 2) "migration_rates rates should be a square matrix"

    C = length(Ns)
    ## normalize migration_rates
    migration_rates_sum = sum(migration_rates, dims = 2)
    for c in 1:C
        migration_rates[c, :] ./= migration_rates_sum[c]
    end

    properties = @dict(Ns,
                       Is,
                       β_und,
                       β_det,
                       β_det,
                       migration_rates,
                       infection_period,
                       infection_period,
                       reinfection_probability,
                       detection_time,
                       C,
                       death_rate)
    space = GraphSpace(complete_digraph(C))
    model = ABM(PoorSoul, space; properties, rng)

    ## Add initial individuals
    for city in 1:C, n in 1:Ns[city]
        ind = add_agent!(city, model, 0, :S) ## Susceptible
    end
    ## add infected individuals
    for city in 1:C
        inds = ids_in_position(city, model)
        for n in 1:Is[city]
            agent = model[inds[n]]
            agent.status = :I ## Infected
            agent.days_infected = 1
        end
    end
    return model
end

using LinearAlgebra: diagind

function create_params(;
                       C,
                       max_travel_rate,
                       infection_period = 30,
                       reinfection_probability = 0.05,
                       detection_time = 14,
                       death_rate = 0.02,
                       Is = [zeros(Int, C - 1)..., 1],
                       seed = 19)
    Random.seed!(seed)
    Ns = rand(50:5000, C)
    β_und = rand(0.3:0.02:0.6, C)
    β_det = β_und ./ 10

    Random.seed!(seed)
    migration_rates = zeros(C, C)
    for c in 1:C
        for c2 in 1:C
            migration_rates[c, c2] = (Ns[c] + Ns[c2]) / Ns[c]
        end
    end
    maxM = maximum(migration_rates)
    migration_rates = (migration_rates .* max_travel_rate) ./ maxM
    migration_rates[diagind(migration_rates)] .= 1.0

    params = @dict(Ns,
                   β_und,
                   β_det,
                   migration_rates,
                   infection_period,
                   reinfection_probability,
                   detection_time,
                   death_rate,
                   Is)

    return params
end

# It remains to provide the SIR stepping functions:

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
    d = DiscreteNonParametric(1:(model.C), model.migration_rates[pid, :])
    m = rand(model.rng, d)
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

    d = Poisson(rate)
    n = rand(model.rng, d)
    n == 0 && return

    for contactID in ids_in_position(agent, model)
        contact = model[contactID]
        if contact.status == :S ||
           (contact.status == :R && rand(model.rng) ≤ model.reinfection_probability)
            contact.status = :I
            n -= 1
            n == 0 && return
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

# That's it!
#
# ## Simulation Using AlgebraicAgents.jl
# 
# We instantiate a sample `ABM` model:

## create a sample agent based model
params = create_params(C = 8, max_travel_rate = 0.01)
abm = model_initiation(; params...)

# Let's specify what data to collect:

infected(x) = count(i == :I for i in x)
recovered(x) = count(i == :R for i in x)
to_collect = [(:status, f) for f in (infected, recovered, length)]

# We wrap the model as an agent:

m = ABMAgent("sir_model", abm; agent_step!, tspan=(0., 100.), adata=to_collect)

# And we simulate the dynamics:

simulate(m)

# 

draw(m)