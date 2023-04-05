using AlgebraicAgents

# declare problems (models in OA's type system)
using DifferentialEquations, Plots

## vanilla function
f(u, p, t) = 1.01 * u
u0 = 1 / 2
tspan = (0.0, 10.0)
prob = ODEProblem(f, u0, tspan)

## atomic models
m1 = DiffEqAgent("model1", prob)
m2 = DiffEqAgent("model2", prob)
m3 = DiffEqAgent("model3", prob)

## declare observables (out ports) for a model
## it will be possible to reference m3's first variable as both `o1`, `o2`
push_exposed_ports!(m3, "o1" => 1, "o2" => 1)

@test m3["o2"] == getobservable(m3, "o2")

## simple function, calls to which will be scheduled during the model integration
custom_function(agent, t) = 1#println(name(agent), " ", t)

## a bit more intricate logic - 
function f_(u, p, t)
    # access the wrapping agent (hierarchy bond)
    agent = @get_agent p

    # access observables 
    ## first via convenient macro syntax
    o1, o2 = @observables agent "../model3":("o1", "o2")
    o1 = @observables agent "../model3":"o1"
    ## more explicit notation
    o1 = getobservable(getagent(agent, "../model3"), 1)
    ## fetch observable's value at **a given time point in the past**
    o3 = gettimeobservable(getagent(agent, "../model3"), t / 2, 1)

    # schedule interaction
    ## first, schedule a call to `_interact!(agent)` with priority 0
    ## this is the default behavior
    poke(agent)
    ## alternatively, provide a function call f(args...)
    ## this will be expanded to a call f(agent, args...)
    @call agent custom_function(agent, t)

    min(2.0, 1.01 * u + o1 + o2 + o3)
end

## yet another atomic model
m4 = @wrap "model4" ODEProblem(f_, u0, tspan) # convenience macro

### alternative way to set-up reference 
# m4 = DiffEqAgent("model4", prob_)

# hierarchical sum of atomic models
m = ⊕(m1, m2; name = "diagram1") ⊕ ⊕(m3, m4; name = "diagram2")

# explore path-like structure of agents

## index by unix-like path
getagent(m, "diagram1/model1/")
getagent(m, "diagram1/model1")
getagent(m1, "../model2")
getagent(m1, "../../diagram2/model3")

## index by regex expression
getagent(m, r"model.*")

## index by glob expression
getagent(m, glob"**/model?/")
getagent(m, glob"**/model?"s)

# solving the problems
sol = AlgebraicAgents.simulate(m)

# plot solution
@testset "`draw` (SciML integration) outputs `Plot`" begin draw(sol, "diagram1/model1") end

# output ports can couple dynamics
@testset "observable (output) ports" begin
    tspan = (0.0, 4.0)

    function ẋ(u, p, t)
        agent = @get_agent p
        y = getobservable(getagent(agent, "../agent_y"), "y")
        return [p.α * y]
    end
    px = (α = 0.5,)
    x0 = [0.1]

    function ẏ(u, p, t)
        agent = @get_agent p
        x = getobservable(getagent(agent, "../agent_x"), "x")
        return [p.β * x]
    end
    py = (β = 1.2,)
    y0 = [1.0]

    agent_x = DiffEqAgent("agent_x", ODEProblem(ẋ, x0, tspan, px), Euler(), dt = 1e-4)
    agent_y = DiffEqAgent("agent_y", ODEProblem(ẏ, y0, tspan, py), Euler(), dt = 1e-4)

    push_exposed_ports!(agent_x, "x" => 1)
    push_exposed_ports!(agent_y, "y" => 1)

    joint_system = ⊕(agent_x, agent_y; name = "joint_system")

    sol = AlgebraicAgents.simulate(joint_system)

    y = getobservable(getagent(joint_system, "agent_y"), "y")
    x = getobservable(getagent(joint_system, "agent_x"), "x")

    A = [0 px.α; py.β 0]
    z0 = [x0[1], y0[1]]

    zt = exp(A * tspan[2]) * z0

    @test isapprox(zt[1], x, rtol = 1e-2)
    @test isapprox(zt[2], y, rtol = 1e-2)
end

@testset "integrators stay in sync during longer runs" begin
    tspan = (0.0, 100.0)

    function ẋ(u, p, t)
        agent = @get_agent p
        y = getobservable(getagent(agent, "../agent_y"), "y")
        return [p.α * y]
    end
    px = (α = 0.5,)
    x0 = [0.1]

    function ẏ(u, p, t)
        agent = @get_agent p
        x = getobservable(getagent(agent, "../agent_x"), "x")
        return [p.β * x]
    end
    py = (β = 1.2,)
    y0 = [1.0]

    agent_x = DiffEqAgent("agent_x", ODEProblem(ẋ, x0, tspan, px))
    agent_y = DiffEqAgent("agent_y", ODEProblem(ẏ, y0, tspan, py))

    push_exposed_ports!(agent_x, "x" => 1)
    push_exposed_ports!(agent_y, "y" => 1)

    joint_system = ⊕(agent_x, agent_y; name = "joint_system")

    sol = AlgebraicAgents.simulate(joint_system)

    @test getagent(joint_system, "agent_y").integrator.t ==
          getagent(joint_system, "agent_x").integrator.t
    @test getagent(joint_system, "agent_y").integrator.t == tspan[2]
end
