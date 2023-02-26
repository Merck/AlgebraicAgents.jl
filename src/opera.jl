# interaction broker

## action types
const InstantiousInteraction = NamedTuple{(:call, :priority), <:Tuple{Function, Any}}
const Future = NamedTuple{(:id, :call, :time),
                          <:Tuple{AbstractString, Function, Any}}
const FutureLog = NamedTuple{(:id, :time, :retval),
                             <:Tuple{AbstractString, Any, Any}}
const Control = NamedTuple{(:id, :call), <:Tuple{AbstractString, Function}}
const ControlLog = NamedTuple{(:id, :time, :retval), <:Tuple{AbstractString, Any, Any}}

"""
    Opera(uuid2agent_pairs...)
A dynamic structure that 
 - contains a **directory of algebraic agents** (dictionary of `uuid => agent` pairs);
 - keeps track of, and executes, **futures (delayed interactions)**;
 - keeps track of, and executes, **system controls**;
 - keeps track of, and executes, **instantious interactions**;

# Futures
You may schedule function calls, to be executed at predetermined points of time.
The action is specified as a tuple `(id, call, time)`, where `id` is an optional textual identifier of the action, `call` is a (parameterless) anonymous function, which will be called at given `time`.
Once the action is executed, the return value with corresponding action id and execution time is added to `futures_log` field of `Opera` instance.

See [`add_future!`](@ref) and [`@future`](@ref).

# Control Interactions
You may schedule control function calls, to be executed at every step of the model.
The action is specified as a tuple `(id, call)`, where `id` is an optional textual identifier of the action, and `call` is a (parameterless) anonymous function.
Once the action is executed, the return value with corresponding action id and execution time is added to `controls_log` field of `Opera` instance.

See [`add_control!`](@ref) and [`@control`](@ref).

# Instantious Interactions
You may schedule additional interactions which exist within a single step of the model;
such actions are modeled as named tuples `(priority=0., call)`. Here, `call` is a (parameterless) anonymous function.

They exist within a single step of the model and are executed after the calls
to `_prestep!` and `_step!` finish.

In particular, you may schedule interactions of two kinds:
 
 - `poke(agent)`, which will translate into a call `_interact!(agent)`,
 - `@call opera expresion priority=0`, which will translate into a call `() -> expression`.

See [`poke`](@ref) and [`@call`](@ref).
"""
mutable struct Opera
    # dictionary of `uuid => agent` pairs
    directory::Dict{UUID, AbstractAlgebraicAgent}
    # intantious interactions
    instantious_interactions::Vector{InstantiousInteraction}
    # futures
    futures::Vector{Future}
    futures_log::Vector{FutureLog}
    # controls
    controls::Vector{Control}
    controls_log::Vector{ControlLog}

    function Opera(uuid2agent_pairs...)
        new(Dict{UUID, AbstractAlgebraicAgent}(uuid2agent_pairs...),
            Vector{InstantiousInteraction}(undef, 0),
            Vector{Future}(undef, 0),
            Vector{FutureLog}(undef, 0),
            Vector{Control}(undef, 0),
            Vector{ControlLog}(undef, 0))
    end
end

# dispatch on the interaction call, and execute it
function call(opera::Opera, call::Function)
    if hasmethod(call, Tuple{})
        call()
    elseif hasmethod(call, Tuple{Opera})
        call(opera)
    elseif length(opera.directory) > 1 &&
           hasmethod(call, Tuple{typeof(topmost(first(opera.directory).value))})
        call(topmost(first(opera.directory).value))
    else
        @error """interaction $call must have one of the following forms:
            - be parameterless,
            - be a function of `Opera` instance,
            - be a function of the topmost agent in the hierarchy.
        """
    end
end

"Schedule an algebraic interaction."
function add_instantious_interaction!(opera::Opera, action::InstantiousInteraction)
    # sorted insert
    pushfirst!(opera.instantious_interactions, action)

    ix = 1
    while ix < length(opera.instantious_interactions)
        if action.priority > opera.instantious_interactions[ix + 1].priority
            opera.instantious_interactions[ix] = opera.instantious_interactions[ix + 1]
            opera.instantious_interactions[ix + 1] = action
            ix += 1
        else
            break
        end
    end
end

# Execute instantious interactions
function execute_instantious_interaction!(opera::Opera)
    while !isempty(opera.instantious_interactions)
        call(opera, pop!(opera.instantious_interactions).call)
    end
end

"""
    poke(agent, priority=0)
Schedule an interaction. Interactions are implemented within an instance `Opera`, sorted by their priorities.
Internally, reduces to `_interact!(agent)`.

See also [`Opera`](@ref).

# Examples
```julia
poke(agent, 1.)
```
"""
function poke(agent, priority = 0.0)
    add_instantious_interaction!(getopera(agent),
                                 (; call = () -> _interact!(agent),
                                  priority = Float64(priority)))
end

"""
    @call agent call priority=0
    @call opera call priority=0
Schedule an interaction (call). Interactions are implemented within an instance `Opera`, sorted by their priorities.
Internally, the `call` expression will be transformed to an anonymous function `() -> call`.

See also [`Opera`](@ref).

# Examples
```julia
bob_agent = only(getagent(agent, r"bob"))
@call agent wake_up(bob_agent)
```
"""
macro call(opera, call, priority = 0.0)
    quote
        opera = $(esc(opera)) isa Opera ? $(esc(opera)) : getopera($(esc(opera)))
        add_instantious_interaction!(opera,
                                     (; call = () -> $(esc(call)),
                                      priority = Float64($(esc(priority)))))
    end
end

"""
    add_future!(opera, time, call[, id])
    add_future!(agent, time, call[, id])
Schedule a (delayed) execution of `call` at `time`. Optionally, provide a textual identifier `id` of the action.

See also [`Opera`](@ref).
"""
function add_future! end

function add_future!(opera::Opera, time, call,
                     id = "future__" * randstring(4))
    new_action = (; id, call, time)
    # sorted insert
    pushfirst!(opera.futures, new_action)
    ix = 1
    while ix < length(opera.futures)
        if new_action.time > opera.futures[ix + 1].time
            opera.futures[ix] = opera.futures[ix + 1]
            opera.futures[ix + 1] = new_action
            ix += 1
        else
            break
        end
    end
end

function add_future!(agent::AbstractAlgebraicAgent, args...)
    add_future!(getopera(agent), args...)
end

"""
    @future opera time call [id]
    @future agent time call [id]
Schedule a (delayed) execution of `call` at `time`. Optionally, provide a textual identifier `id` of the action.

`call` is an expression, which will be wrapped into an anonymous, parameterless function `() -> call`.

See also [`@future`](@ref) and [`Opera`](@ref).
"""
macro future(opera, time, call, id = "future__" * randstring(4))
    quote
        add_future!($(esc(opera)), $(esc(time)), () -> $(esc(call)),
                    $(esc(id)))
    end
end

# execute futures (delayed interactions)
function execute_futures!(opera::Opera, time)
    while !isempty(opera.futures)
        action = first(opera.futures)
        if action.time <= time
            # execute, log
            log_record = (; id = action.id, time, retval = call(opera, action.call))
            push!(opera.futures_log, log_record)

            # delete action
            popfirst!(opera.futures)
        else
            break
        end
    end

    # least time among scheduled actions
    if isempty(opera.futures)
        nothing
    else
        first(opera.futures).time
    end
end

"""
    add_control!(opera, call[, id])
    add_future!(agent, call[, id])
Add a control to the system. Optionally, provide a textual identifier `id` of the action.

See also [`@control`](@ref) and [`Opera`](@ref).
"""
function add_control! end

function add_control!(opera::Opera, call, id = "control_" * randstring(4))
    new_action = (; id, call)
    push!(opera.controls, new_action)
end

function add_control!(agent::AbstractAlgebraicAgent, args...)
    add_control!(getopera(agent), args...)
end

"""
    @control opera call [id]
    @control agent call [id]
Add a control to the system. Optionally, provide a textual identifier `id` of the action.

`call` is an expression, which will be wrapped into an anonymous, parameterless function `() -> call`.

See also [`Opera`](@ref).
"""
macro control(opera, call, id = "control_" * randstring(4))
    quote
        add_control!($(esc(opera)), () -> $(esc(call)), $(esc(id)))
    end
end

# execute system controls
function execute_controls!(opera::Opera, time)
    foreach(opera.controls) do action
        log_record = (; id = action.id, time, retval = call(opera, action.call))
        push!(opera.controls_log, log_record)
    end
end
