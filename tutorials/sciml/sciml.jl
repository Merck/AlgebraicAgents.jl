# # SciML Integration

using AlgebraicAgents

#

## declare problems (models in AA's type system)
using DifferentialEquations

## vanilla function
f(u,p,t) = 1.01*u
u0 = 1/2
tspan = (0.0,10.0)
prob = ODEProblem(f,u0,tspan)

# ## Atomic Models

m1 = DiffEqAgent("model1", prob)
m2 = DiffEqAgent("model2", prob)
m3 = DiffEqAgent("model3", prob)

## declare observables (out ports) for a model
## it will be possible to reference m3's first variable as both `o1`, `o2`
push_exposed_ports!(m3, "o1" => 1, "o2" => 1)

## simple function, calls to which will be scheduled during the model integration
custom_function(agent, t) = println("inside $agent at time $t")

## a bit more intricate logic - 
function f_(u,p,t)
    ## access the wrapping agent (hierarchy bond)
    agent = @get_agent p
    
    ## access observables 
    ## first via convenient macro syntax
    o1, o2 = @observables agent "../model3":("o1", "o2")
    o1 = @observables agent "../model3":"o1"
    ## more explicit notation
    o1 = getobservable(getagent(agent, "../model3"), 1)
    ## fetch observable's value at **a given time point in the past**
    o3 = gettimeobservable(getagent(agent, "../model3"), t/2, 1)

    ## schedule interaction
    ## first, schedule a call to `_interact!(agent)` with priority 0
    ## this is the default behavior
    poke(agent)
    ## alternatively, provide a function call f(args...)
    ## this will be expanded to a call f(agent, args...)
    @call agent custom_function(agent, t)

    min(2., 1.01*u + o1 + o2 + o3)
end

# ## Another Atomic Model

prob_ = ODEProblem(f_,u0,tspan)
m4 = DiffEqAgent("model4", prob_)

# alternative way to set-up reference 

## m4 = DiffEqAgent("model4", prob_; oref=:__aagent__)
## m4 = @wrap prob_ ODEProblem(f_,u0,tspan) oref=:__agent__

# ## Hierarchical Sum of Atomic Models

m = ⊕(m1, m2; name="diagram1") ⊕ ⊕(m3, m4; name="diagram2")

#

## explore path-like structure of agents

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

# ## Solving
sol = simulate(m)