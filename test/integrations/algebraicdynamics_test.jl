# based on https://algebraicjulia.github.io/AlgebraicDynamics.jl/dev/examples/Lotka-Volterra/
using AlgebraicDynamics
using AlgebraicDynamics.DWDDynam, AlgebraicDynamics.UWDDynam
using Catlab.WiringDiagrams, Catlab.Programs
using LabelledArrays
using Plots

using AlgebraicAgents, DifferentialEquations

const UWD = UndirectedWiringDiagram

@testset "AlgebraicDynamics.jl integration: DWD test" begin
    # Define the primitive systems
    dotr(u, x, p, t) = [p.α * u[1] - p.β * u[1] * x[1]]
    dotf(u, x, p, t) = [p.γ * u[1] * x[1] - p.δ * u[1]]

    rabbit = ContinuousMachine{Float64}(1, 1, 1, dotr, (u, p, t) -> u)
    fox = ContinuousMachine{Float64}(1, 1, 1, dotf, (u, p, t) -> u)

    # Define the composition pattern
    rabbitfox_pattern = WiringDiagram([], [:rabbits, :foxes])
    rabbit_box = add_box!(rabbitfox_pattern, Box(:rabbit, [:pop], [:pop]))
    fox_box = add_box!(rabbitfox_pattern, Box(:fox, [:pop], [:pop]))

    add_wires!(rabbitfox_pattern,
               Pair[(rabbit_box, 1) => (fox_box, 1),
                    (fox_box, 1) => (rabbit_box, 1),
                    (rabbit_box, 1) => (output_id(rabbitfox_pattern), 1),
                    (fox_box, 1) => (output_id(rabbitfox_pattern), 2)])

    rabbitfox_system = oapply(rabbitfox_pattern, [rabbit, fox])

    # AlgebraicAgents.jl wrap
    rabbit_wrap = wrap_system("rabbit", ContinuousMachine{Float64}(1, 1, 1, dotr, (u, p, t) -> u))
    fox_wrap = wrap_system("fox", ContinuousMachine{Float64}(1, 1, 1, dotf, (u, p, t) -> u))

    # Compose
    rabbitfox_system_wrap = ⊕(rabbit_wrap, fox_wrap; diagram = rabbitfox_pattern,
                              name = "rabbitfox_system_wrap")

    # Solve and plot
    u0 = [10.0, 100.0]
    params = LVector(α = 0.3, β = 0.015, γ = 0.015, δ = 0.7)
    tspan = (0.0, 100.0)

    @testset "AlgebraicDynamics.jl and (wrapped) AlgebraicAgents.jl solutions are equal" begin
        # pure
        prob_ode = ODEProblem(rabbitfox_system, u0, tspan, params)
        sol_ode = solve(prob_ode, Tsit5())

        # wrap
        prob_agents = DiffEqAgent(rabbitfox_system_wrap, u0, tspan, params)
        simulate(prob_agents)
        sol_agents = prob_agents.integrator.sol

        @test isapprox(sol_ode.u, sol_agents.u, rtol = 1e-2)
    end
end

@testset "AlgebraicDynamics.jl integration: UWD test" begin
    # Define the primitive systems
    dotr(u, p, t) = p.α * u
    dotrf(u, p, t) = [-p.β * u[1] * u[2], p.γ * u[1] * u[2]]
    dotf(u, p, t) = -p.δ * u

    rabbitfox_pattern = @relation (rabbits, foxes) begin
        growth(rabbits)
        predation(rabbits, foxes)
        decline(foxes)
    end

    # pure AlgebraicDynamics
    rabbit_growth = ContinuousResourceSharer{Float64}(1, dotr)
    rabbitfox_predation = ContinuousResourceSharer{Float64}(2, dotrf)
    fox_decline = ContinuousResourceSharer{Float64}(1, dotf)

    rabbitfox_system = oapply(rabbitfox_pattern,
                              [rabbit_growth, rabbitfox_predation, fox_decline])

    rabbit_growth_wrap = wrap_system("rabbit_growth", ContinuousResourceSharer{Float64}(1, dotr))
    rabbitfox_predation_wrap = wrap_system("rabbitfox_predation", ContinuousResourceSharer{Float64
                                                                                    }(2,
                                                                                      dotrf))
    fox_decline_wrap = wrap_system("fox_decline", ContinuousResourceSharer{Float64}(1, dotf))

    # Compose
    rabbitfox_system_wrap = ⊕(rabbit_growth_wrap, rabbitfox_predation_wrap,
                              fox_decline_wrap, diagram = rabbitfox_pattern,
                              name = "rabbitfox_system")

    # Solve and plot
    u0 = [10.0, 100.0]
    params = LVector(α = 0.3, β = 0.015, γ = 0.015, δ = 0.7)
    tspan = (0.0, 100.0)

    @testset "AlgebraicDynamics.jl and (wrapped) AlgebraicAgents.jl solutions are equal" begin
        # pure
        prob_ode = ODEProblem(rabbitfox_system, u0, tspan, params)
        sol_ode = solve(prob_ode, Tsit5())

        # wrap
        prob_agents = DiffEqAgent(rabbitfox_system_wrap, u0, tspan, params)
        simulate(prob_agents)
        sol_agents = prob_agents.integrator.sol

        @test isapprox(sol_ode.u, sol_agents.u, rtol = 1e-2)
    end
end
