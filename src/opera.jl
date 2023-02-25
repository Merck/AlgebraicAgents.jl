# implements an interaction broker

"Abstract opera interaction. See [`Opera`](@ref)."
abstract type AbstractOperaCall end

"A scheduled call to an agent. See [`Opera`](@ref)."
struct AgentCall <: AbstractOperaCall
    agent::AbstractAlgebraicAgent
    call::Any

    AgentCall(agent::AbstractAlgebraicAgent, call = nothing) = new(agent, call)
end

"""
    Opera(uuid2agent_pairs...)
A dynamic structure that 
 - contains a **directory of algebraic agents** (dictionary of `uuid => agent` pairs);
 - stores a **priority queue of interactions**.

# Algebraic Interactions
It is possible to schedule additional interactions within the complex;
such actions are instances of `AbstractOperaCall`,
and they are modeled as tuples `(priority=0., call)`.

At the end of the topmost call to `step!`, the actions will be executed one-by-one in order of their priorities.

In particular, you may schedule interactions of two kinds:
 
 - `poke(agent)`, which will translate into a call `_interact!(agent)`,
 - `@call agent f(args...) priority=0` or `@call agent x->ex priority=0`,
which will translate into a call `agent->f(agent, args...)` or `(x->ex)(agent)`, respectively.

See [`poke`](@ref) and [`@call`](@ref).

They exist within a single step of the model and are executed after the calls
to `_prestep!` and `_step!` finish. 

See [`opera_enqueue!`](@ref).
"""
mutable struct Opera
    calls::PriorityQueue{AbstractOperaCall, Float64}
    directory::Dict{UUID, AbstractAlgebraicAgent}

    function Opera(uuid2agent_pairs...)
        new(PriorityQueue{AbstractOperaCall, Float64}(Base.Order.Reverse),
            Dict{UUID, AbstractAlgebraicAgent}(uuid2agent_pairs...))
    end
end

"Schedule an algebraic interaction."
function opera_enqueue!(::Opera, ::AbstractOperaCall, ::Float64) end

function opera_enqueue!(opera::Opera, call::AgentCall, priority::Float64 = 0.0)
    !haskey(opera.calls, call) && enqueue!(opera.calls, call => priority)
end

"Execute an algebraic interaction."
function execute_action!(::Opera, ::AbstractOperaCall) end

function execute_action!(::Opera, call::AgentCall)
    if isnothing(call.call)
        _interact!(call.agent)
    else
        call.call(call.agent)
    end
end

"Execute scheduled algebraic interactions."
function opera_run!(opera::Opera)
    while !isempty(opera.calls)
        execute_action!(opera, dequeue!(opera.calls))
    end
end
