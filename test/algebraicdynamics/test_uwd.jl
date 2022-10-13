# based on https://algebraicjulia.github.io/AlgebraicDynamics.jl/dev/examples/Lotka-Volterra/
using AlgebraicDynamics
using AlgebraicDynamics.UWDDynam
using Catlab.WiringDiagrams, Catlab.Programs
using LabelledArrays
using Plots

using AlgebraicAgents

const UWD = UndirectedWiringDiagram

# Define the primitive systems
dotr(u,p,t) = p.α*u
dotrf(u,p,t) = [-p.β*u[1]*u[2], p.γ*u[1]*u[2]]
dotf(u,p,t) = -p.δ*u

rabbit_growth = @wrap rabbit_growth ContinuousResourceSharer{Float64}(1, dotr)
rabbitfox_predation = @wrap "rabbitfox_predation" ContinuousResourceSharer{Float64}(2, dotrf)
fox_decline = @wrap "fox_decline" ContinuousResourceSharer{Float64}(1, dotf)

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

import DifferentialEquations

prob = DiffEqAgent(rabbitfox_system, u0, tspan, params)

sol = simulate(prob)

draw(sol)