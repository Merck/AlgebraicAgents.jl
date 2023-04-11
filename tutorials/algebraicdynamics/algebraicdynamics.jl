# # Lotka-Voltera Two Ways
# 
# We demonstrate an integration of [AlgebraicDynamics.jl](https://github.com/AlgebraicJulia/AlgebraicDynamics.jl).
# 
# The tutorial is based on [AlgebraicDynamics.jl: Lotka-Volterra Three Ways](https://algebraicjulia.github.io/AlgebraicDynamics.jl/dev/examples/Lotka-Volterra/).
#
# ## Undirected Composition

using AlgebraicDynamics
using AlgebraicDynamics.UWDDynam
using Catlab.WiringDiagrams, Catlab.Programs
using LabelledArrays
using Plots

const UWD = UndirectedWiringDiagram

#

using AlgebraicAgents

# Define the primitive systems

dotr(u,p,t) = p.α*u
dotrf(u,p,t) = [-p.β*u[1]*u[2], p.γ*u[1]*u[2]]
dotf(u,p,t) = -p.δ*u

rabbit_growth = wrap_system("rabbit_growth", ContinuousResourceSharer{Float64}(1, dotr))
rabbitfox_predation = wrap_system("rabbitfox_predation", ContinuousResourceSharer{Float64}(2, dotrf))
fox_decline = wrap_system("fox_decline", ContinuousResourceSharer{Float64}(1, dotf))

# Define the composition pattern

rf = @relation (rabbits,foxes) begin
    growth(rabbits)
    predation(rabbits,foxes)
    decline(foxes)
end

# Compose

rabbitfox_system = ⊕(rabbit_growth, rabbitfox_predation, fox_decline, diagram=rf, name="rabbitfox_system")

# Solve and plot

u0 = [10.0, 100.0]
params = LVector(α=.3, β=0.015, γ=0.015, δ=0.7)
tspan = (0.0, 100.0)

#

import DifferentialEquations
prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)

#

sol = simulate(prob)

#

draw(sol; label=["rabbits" "foxes"])

# ## Directed Composition

using AlgebraicDynamics, AlgebraicDynamics.DWDDynam
using Catlab.WiringDiagrams, Catlab.Programs
using LabelledArrays
using Plots

#

using AlgebraicAgents, DifferentialEquations

# Define the primitive systems

dotr(u, x, p, t) = [p.α*u[1] - p.β*u[1]*x[1]]
dotf(u, x, p, t) = [p.γ*u[1]*x[1] - p.δ*u[1]]

rabbit = wrap_system("rabbit", ContinuousMachine{Float64}(1,1,1, dotr, (u, p, t) -> u))
fox    = wrap_system("fox", ContinuousMachine{Float64}(1,1,1, dotf, (u, p, t) -> u))

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

# Compose

rabbitfox_system = ⊕(rabbit, fox; diagram=rabbitfox_pattern, name="rabbitfox_system")

# Solve and plot

u0 = [10.0, 100.0]
params = LVector(α=.3, β=0.015, γ=0.015, δ=0.7)
tspan = (0.0, 100.0)

#

## convert the system to a problem
prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)

#

## solve the problem
simulate(prob)

#

## plot
draw(prob; label=["rabbits" "foxes"])

# ## Open CPG

using AlgebraicDynamics.CPortGraphDynam
using AlgebraicDynamics.CPortGraphDynam: barbell

# Define the composition pattern

rabbitfox_pattern = barbell(1)

rabbitfox_system = ⊕(rabbit, fox; diagram=rabbitfox_pattern, name="rabbitfox_system")

# Solve and plot

u0 = [10.0, 100.0]
params = LVector(α=.3, β=0.015, γ=0.015, δ=0.7)
tspan = (0.0, 100.0)

#

## convert the system to a problem
prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)

#

## solve the problem
simulate(prob)

#

## plot
draw(prob; label=["rabbits" "foxes"])