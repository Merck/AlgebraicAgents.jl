```@meta
EditURL = "<unknown>/anderson.jl"
```

# [Continuous time stochastic simulation example](@id stochastic_example)

To demonstrate the generality of AlgebraicAgents.jl, we demonstrate here how
to use the package to set up a type system capable of simulating continuous
time discrete state stochastic processes using the method described by
[Anderson (2007)](https://people.math.wisc.edu/~dfanderson/papers/AndNRM.pdf).

We begin by importing packages we will use.

````@example anderson
using AlgebraicAgents, Distributions, DataFrames, Plots, StatsPlots
````

## Reaction System
We use the `@aagent` struct to define a new type which is a concrete subtype of `AbstractAlgebraicAgent`
called `ReactionSystem`. It contains data members:

  - `t`: current simulation time
  - `Δ`: the interarrival time between events
  - `X``: current system state
  - `X0`: initial system state
  - `df_output`: a `DataFrame` contining the sampled trajectory

````@example anderson
@aagent struct ReactionSystem{T,S}
    t::T
    Δ::T
    X::Vector{S}
    X0::Vector{S}
````

simulation trajectory

````@example anderson
    df_output::DataFrame
end
````

We define a method `make_reactionsystem` which constructs a concrete instantiation
of the `ReactionSystem` type, with a given `name` and initial state `X0`.
Note that we use `entangle!` to add an instantiation of the `FreeAgent` type
exported from AlgebraicAgents to the object. This agent is called "clocks" and
will contain agents which jointly make up the stochastic dynamics of the system.

````@example anderson
function make_reactionsystem(name::T, X0::Vector{S}) where {T,S}
    df_output = DataFrame(time=Float64[],clock=String[])
    for i in eachindex(X0)
        insertcols!(df_output, Symbol("X"*string(i))=>S[])
    end
    rs = ReactionSystem{Float64,S}(name, 0.0, 0.0, X0, X0, df_output)
    entangle!(rs, FreeAgent("clocks"))
    return rs
end
````

Because the `ReactionSystem` itself has no dynamics (it represents the "world state"),
its implementation of `AlgebraicAgents._step!` does nothing.

````@example anderson
AlgebraicAgents._step!(a::ReactionSystem) = nothing
````

We also need to implement `AlgebraicAgents._projected_to` for `ReactionSystem`. In
this case because the times to which the system is solved are determined by the individual
stochastic processes which make up the system (defined later),
we can set it to the trivial implementation which does nothing.

````@example anderson
AlgebraicAgents._projected_to(a::ReactionSystem) = nothing
````

## Clock Process

The key concept in [Anderson (2007)](https://people.math.wisc.edu/~dfanderson/papers/AndNRM.pdf)
is that the stochastic system is defined by a set of clocks, each of which fires
at the points of an inhomogeneous Poisson process. Strictly speaking, each clock
process $k$ also has an associated marking $\nu_{k}$, which updates the state of
the system. Let $M$ be the total number of clock processes.

Consider the state $X(t)$ at a time $t$ to be a vector of integers. Let each clock process
have an associated counting process $R_{k}(t)$ which tells us the number of times
it has fired up to time $t$. Then we can write the current model state as a function
of the set of all counting processes, their markings, and the initial condition as:

```math
X(t) = X(0) + \sum_{k=1}^{M} R_{k}(t) \nu_{k}
```

We can write each counting process as arising from an inhomogenous Poisson process
with intensity function $a_{k}(X)$. Specific forms of $a_{k}$ and $\nu_{k}$ will make meaningful
models for chemical reactions, ecological systems, epidemiological processes, sociology,
or other domains.

```math
R_{k}(t) = Y_{k}\left(\int_{0}^{t}a_{k}(X(s))ds\right)
```
The above is therefore an expression of the counting process in terms of a unit rate
Poisson process $Y_{k}$. Via the random time change theorem by transforming time according
to the integrated intensity $T_{k}(t) = \int_{0}^{t}a_{k}(X(s))ds$ we get the proper
inhomogeneous Poisson process, such that when the intensity is high, more events occur
(i.e. the inter-arrival time is smaller), and vice-versa for low intensity.

To apply the method of [Anderson (2007)](https://people.math.wisc.edu/~dfanderson/papers/AndNRM.pdf)
we need one more definition, $P_{k}$, which is the _next_ firing time of $T_{k}$, applying
the random time change such that it advances at unit exponentially-distributed increments.

```math
  P_{k} = \{s > T_{k} : Y_{k}(s) > Y_{k}(T_{k}) \}
```

Now let us define $R_{k}$ using the `@aagent` macro from AlgebraicAgents.
It contains data members:

  - `P`: the next internal firing time of the homogeneous Poisson process
  - `T`: the internal time of the homogeneous Poisson process
  - `Δt`: absolute (wall-clock) time time before next putative firing
  - `τ`: next asbolute putative time to fire
  - `a`: current value of $a_{k}$
  - `intensity`: the intensity function $a_{k}$, which accepts as input $X$ and returns floating point value
  - `ν`: the marking which updates state (a vector)

````@example anderson
@aagent struct Clock{N<:Real,Fn<:Function,S<:Number}
    P::N
    T::N
    Δt::N
    τ::N
    a::N
    intensity::Fn
    ν::Vector{S}
end
````

We must now define a method which adds a clock process to an object of
type `ReactionSystem`. This "initialization" method implements steps 1-5
of Algorithm 3 in Anderson's paper. Readers should note that we include
step 5 as initialization and then compute it again at the _end_ of the
loop via using a control interaction because of how AlgebraicAgents structures
updates.

````@example anderson
function add_clock!(rs::ReactionSystem, name::T, intensity::U, ν::Vector{S}) where {T,U,S}
    c = Clock{Float64,U,S}(name, 0.0, 0.0, 0.0, 0.0, 0.0, intensity, ν)
````

calculate intensity

````@example anderson
    c.a = c.intensity(rs.X)
````

draw internal jump times

````@example anderson
    c.P = rand(Exponential())
````

update time of first firing (i dont like this)

````@example anderson
    c.Δt = (c.P - c.T) / c.a
    c.τ += c.Δt
````

entangle the clock

````@example anderson
    entangle!(inners(rs)["clocks"], c)
````

add the control (update integrated intensity)

````@example anderson
    add_control!(rs, () -> control_clock(c), "control " * name)
end
````

We must implement `AlgebraicAgents._projected_to` for the type `Clock`.
Here it will return the putative times to fire. This is because the simulation method
(and many other continuous time discrete event simulation algorithms) updates
via a race condition, where the next event to cause a state change is the one
that "actually happens". AlgebraicAgents selects the agent(s) to `_step!` as the
ones whose projected time is the minimum of all projected times, so that the
clock that fires first will be the one whose dynamics occur for this next iteration
of the simulation loop. Because the next times are sampled from the points of Poisson processes
they almost surely occur at unique times, and therefore conflicts cannot occur.

It is interesting to note here that AlgebraicAgents can implement any algorithm
that depends on such a race condition.

````@example anderson
function AlgebraicAgents._projected_to(c::Clock)
    c.τ
end
````

Now we implement `AlgebraicAgents._step!` for type `Clock`. In this method, steps 6,7, and 9
of Algorithm 3 from the paper are implemented (specific order of 8 and 9 is not important).
Basically, we update the global time to the time this clock fired, update the state $X$,
and draw the new next firing time $P_{k}$. We also push output to the top level agent, which
is of type `ReactionSystem`. Each update log will have the time of the event, the name of
the clock that caused it, and the new system state.

````@example anderson
function AlgebraicAgents._step!(c::Clock)

    if isinf(c.τ)
        return nothing
    end

    topmost(c).Δ = c.τ - topmost(c).t
    topmost(c).t = c.τ
    topmost(c).X += c.ν
    c.P += rand(Exponential())

    push!(topmost(c).df_output, [topmost(c).t, getname(c), topmost(c).X...])
end
````

Finally we must implement the control interaction which is applied to each clock at the end
of an iteration in the loop. This implements steps 8,9, and 5 of Algorithm 3 (note that we
are allowed to move step 5 to the end because we also included it in the "initialization" phase
earlier).

````@example anderson
function control_clock(c::Clock)
    c.T += c.a * topmost(c).Δ # Tk += ak*Δ
    c.a = c.intensity(topmost(c).X) # update intensity
````

update putative next firing time

````@example anderson
    c.Δt = (c.P - c.T) / c.a
    c.τ = topmost(c).t + c.Δt
end
````

## Simulation

We will simulate a continuous time stochastic SIR (Susceptible-Infectious-Recovered)
model. For mathematical details on this model, please consult [Allen (2017)](https://www.sciencedirect.com/science/article/pii/S2468042716300495).
Let us use parameters $\beta$ to represent the effective contact rate, and
$\gamma$ to represent the recovery rate.

````@example anderson
β = 0.05*10.0
γ = 0.25
````

Now we make a `ReactionSystem` object, and initialize it to a population with
990 susceptible persons, 10 infectious persons, and 0 recovered persons.
The two events in the system are infection and recovery, which fire according
to the rates given by the anonymous functions passed to `add_clock!`.

````@example anderson
rs = make_reactionsystem("SIR", [990, 10, 0])
add_clock!(rs, "infection", (x) -> β*x[2]/sum(x)*x[1], [-1,1,0])
add_clock!(rs, "recovery", (x) -> γ*x[2], [0,-1,1])
````

Now we call `simulate` on the constructed system. Because a clock will return a next
event time of `Inf` when its rate is 0 (meaning it will never fire again), when all clocks
return `Inf` it means the simulation is over, because nothing else can happen. Therefore
we pass as the second argument to `simulate` the largest representable floating point
value. When all clocks return `Inf`, the minimum will be larger than this value and
the simulation loop will end.

````@example anderson
simulate(rs, floatmax(Float64))
````

After simulation is complete, we can extract the simulated trajectory.

````@example anderson
df_out = select(rs.df_output, Not(:clock))
@df df_out plot(:time, cols([:X1,:X2,:X3]), label = ["S" "I" "R"])
````

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

