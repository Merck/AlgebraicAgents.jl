# based on https://algebraicjulia.github.io/AlgebraicDynamics.jl/dev/examples/Lotka-Volterra/
using AlgebraicDynamics, AlgebraicDynamics.DWDDynam
using Catlab.WiringDiagrams, Catlab.Programs
using LabelledArrays
using Plots

using AlgebraicAgents, DifferentialEquations

# Define the primitive systems
dotr(u, x, p, t) = [p.α*u[1] - p.β*u[1]*x[1]]
dotf(u, x, p, t) = [p.γ*u[1]*x[1] - p.δ*u[1]]

rabbit = @wrap rabbit ContinuousMachine{Float64}(1,1,1, dotr, (u, p, t) -> u)
fox    = @wrap fox ContinuousMachine{Float64}(1,1,1, dotf, (u, p, t) -> u)

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

# convert the system to a problem
prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)

# solve the problem
simulate(prob)

# plot
draw(prob)