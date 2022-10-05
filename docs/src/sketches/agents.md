# Agents.jl Integration

We make use of a SIR model constructor from an Agents.jl' [SIR model for the spread of COVID-19](https://juliadynamics.github.io/Agents.jl/stable/examples/sir/) tutorial.

```@example 1
using AlgebraicAgents

# provide integration of AgentBasedModel, incl. AbstractAgent
add_integration(:AgentsIntegration); using AgentsIntegration
```

```@setup 1
include("tutorials/agents_tutorial/sir_agents_model.jl")
```
```@example 1
# create a sample agent based model
params = create_params(C = 8, max_travel_rate = 0.01)
abm = model_initiation(; params...)
```

```@example 1
infected(x) = count(i == :I for i in x)
recovered(x) = count(i == :R for i in x)
to_collect = [(:status, f) for f in (infected, recovered, length)]
```

```@example 1
m = ABMAgent("sir_model", abm; agent_step!, tspan=(0., 100.), adata=to_collect)
```

```@example 1
# simulate the model
simulate(m)
```