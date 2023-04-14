```@meta
EditURL = "<unknown>/../tutorials/sciml/sciml.jl"
```

# SciML Integration

````@example sciml
using AlgebraicAgents
````

````@example sciml
# declare problems (models in AA's type system)
using DifferentialEquations

# vanilla function
f(u,p,t) = 1.01*u
u0 = 1/2
tspan = (0.0,10.0)
prob = ODEProblem(f,u0,tspan)
````

## Atomic Models

````@example sciml
m1 = DiffEqAgent("model1", prob)
m2 = DiffEqAgent("model2", prob)
m3 = DiffEqAgent("model3", prob)

# declare observables (out ports) for a model
# it will be possible to reference m3's first variable as both `o1`, `o2`
push!(observables(m3), "o1" => 1, "o2" => 1)

# simple function, calls to which will be scheduled during the model integration
custom_function(agent, t) = println("inside $agent at time $t")

# a bit more intricate logic -
function f_(u,p,t)
    # access the wrapping agent (hierarchy bond)
    agent = extract_agent(p)

    # access observables
    o1 = getobservable(getagent(agent, "../model3"), "o1")
    o2 = getobservable(getagent(agent, "../model3"), "o2")
    # fetch observable's value at **a given time point in the past**
    o3 = gettimeobservable(getagent(agent, "../model3"), t/2, 1)

    # schedule interaction
    # first, schedule a call to `_interact!(agent)` with priority 0
    # this is the default behavior
    poke(agent)
    # alternatively, provide a function call f(args...)
    # this will be expanded to a call f(agent, args...)
    @call agent custom_function(agent, t)

    min(2., 1.01*u + o1 + o2 + o3)
end
````

## Another Atomic Model

````@example sciml
m4 = DiffEqAgent("model4", ODEProblem(f_,u0,tspan))
````

## Hierarchical Sum of Atomic Models

````@example sciml
m = ⊕(m1, m2; name="diagram1") ⊕ ⊕(m3, m4; name="diagram2")
````

````@example sciml
# explore path-like structure of agents

# index by unix-like path
getagent(m, "diagram1/model1/")
getagent(m, "diagram1/model1")
getagent(m1, "../model2")
getagent(m1, "../../diagram2/model3")

# index by regex expression
getagent(m, r"model.*")

# index by glob expression
getagent(m, glob"**/model?/")
getagent(m, glob"**/model?"s)
````

## Solving

````@example sciml
sol = simulate(m)
````

