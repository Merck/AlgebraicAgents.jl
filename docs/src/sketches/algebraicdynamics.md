# Lotka-Voltera Two Ways

We showcase the integration of [AlgebraicDynamics.jl](https://github.com/AlgebraicJulia/AlgebraicDynamics.jl), we adopt [Lotka-Volterra Three Ways](https://algebraicjulia.github.io/AlgebraicDynamics.jl/dev/examples/Lotka-Volterra/) tutorial.

## Undirected Composition

```@example 1
using AlgebraicDynamics
using AlgebraicDynamics.UWDDynam
using Catlab.WiringDiagrams, Catlab.Programs
using LabelledArrays
using Plots

const UWD = UndirectedWiringDiagram
```

```@example 1
using AlgebraicAgents
```

```@example 1
# Define the primitive systems
dotr(u,p,t) = p.α*u
dotrf(u,p,t) = [-p.β*u[1]*u[2], p.γ*u[1]*u[2]]
dotf(u,p,t) = -p.δ*u
```

```@example 1
rabbit_growth = @wrap rabbit_growth ContinuousResourceSharer{Float64}(1, dotr)
rabbitfox_predation = @wrap "rabbitfox_predation" ContinuousResourceSharer{Float64}(2, dotrf)
fox_decline = @wrap "fox_decline" ContinuousResourceSharer{Float64}(1, dotf)
```

```@example 1
# Define the composition pattern
rf = @relation (rabbits,foxes) begin
    growth(rabbits)
    predation(rabbits,foxes)
    decline(foxes)
end
```

```@example 1
# Compose
rabbitfox_system = ⊕(rabbit_growth, rabbitfox_predation, fox_decline, diagram=rf, name="rabbitfox_system")
```

```@example 1
# Solve and plot
u0 = [10.0, 100.0]
params = LVector(α=.3, β=0.015, γ=0.015, δ=0.7)
tspan = (0.0, 100.0)
```

```@example 1
import DifferentialEquations
prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)
```

```@example 1
sol = simulate(prob)
```

```@example 1
draw(sol; label=["rabbits" "foxes"])
```

## Directed Composition

```@example 2
using AlgebraicDynamics, AlgebraicDynamics.DWDDynam
using Catlab.WiringDiagrams, Catlab.Programs
using LabelledArrays
using Plots
```

```@example 2
using AlgebraicAgents, DifferentialEquations
```

```@example 2
# Define the primitive systems
dotr(u, x, p, t) = [p.α*u[1] - p.β*u[1]*x[1]]
dotf(u, x, p, t) = [p.γ*u[1]*x[1] - p.δ*u[1]]

rabbit = @wrap rabbit ContinuousMachine{Float64}(1,1,1, dotr, (u, p, t) -> u)
fox    = @wrap fox ContinuousMachine{Float64}(1,1,1, dotf, (u, p, t) -> u)
```

```@example 2
# Define the composition pattern
rabbitfox_pattern = WiringDiagram([], [:rabbits, :foxes])
rabbit_box = add_box!(rabbitfox_pattern, Box(:rabbit, [:pop], [:pop]))
fox_box = add_box!(rabbitfox_pattern, Box(:fox, [:pop], [:pop]))

add_wires!(rabbitfox_pattern, Pair[
    (rabbit_box, 1) => (fox_box, 1),
    (fox_box, 1)    => (rabbit_box, 1),
    (rabbit_box, 1) => (output_id(rabbitfox_pattern), 1),
    (fox_box, 1)    => (output_id(rabbitfox_pattern), 2)
])
```

```@example 2
# Compose
rabbitfox_system = ⊕(rabbit, fox; diagram=rabbitfox_pattern, name="rabbitfox_system")
```

```@example 2
# Solve and plot
u0 = [10.0, 100.0]
params = LVector(α=.3, β=0.015, γ=0.015, δ=0.7)
tspan = (0.0, 100.0)
```

```@example 2
# convert the system to a problem
prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)
```

```@example 2
# solve the problem
simulate(prob)
```

```@example 2
# plot
draw(prob; label=["rabbits" "foxes"])
```

## Open CPG

```@example 2
using AlgebraicDynamics.CPortGraphDynam
using AlgebraicDynamics.CPortGraphDynam: barbell

# Define the composition pattern
rabbitfox_pattern = barbell(1)
```

```@example 2
rabbitfox_system = ⊕(rabbit, fox; diagram=rabbitfox_pattern, name="rabbitfox_system")
```

```@example 2
# Solve and plot
u0 = [10.0, 100.0]
params = LVector(α=.3, β=0.015, γ=0.015, δ=0.7)
tspan = (0.0, 100.0)
```

```@example 2
# convert the system to a problem
prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)
```

```@example 2
# solve the problem
simulate(prob)
```

```@example 2
# plot
draw(prob; label=["rabbits" "foxes"])
```