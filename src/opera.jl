# interaction broker

## action types
const InstantiousInteraction = NamedTuple{(:id, :call, :priority),
    <:Tuple{AbstractString, Function, Number}}
const InstantiousInteractionLog = NamedTuple{(:id, :time, :retval),
    <:Tuple{AbstractString, Number, Any}}
const Future = NamedTuple{(:id, :call, :time),
    <:Tuple{AbstractString, Function, Any}}
const FutureLog = NamedTuple{(:id, :time, :retval),
    <:Tuple{AbstractString, Any, Any}}
const Control = NamedTuple{(:id, :call), <:Tuple{AbstractString, Function}}
const ControlLog = NamedTuple{(:id, :time, :retval), <:Tuple{AbstractString, Any, Any}}

"""
    Opera(uuid2agent_pairs...)
A dynamic structure that 
 - contains a **directory of agents** (dictionary of `uuid => agent` pairs);
 - keeps track of, and executes, **futures (delayed interactions)**;
 - keeps track of, and executes, **system controls**;
 - keeps track of, and executes, **instantious interactions**;

# Futures
You may schedule function calls, to be executed at predetermined points of time.
An action is modeled as a tuple `(id, call, time)`, where `id` is an optional textual identifier of the action and `call` is a (parameterless) anonymous function, which will be called at the given `time`.
Once the action is executed, the return value with corresponding action id and execution time is added to `futures_log` field of `Opera` instance.

See [`add_future!`](@ref) and [`@future`](@ref).

## Example

```julia
alice = MyAgentType("alice")
interact = agent -> wake_up!(agent)
@future alice 5.0 interact(alice) "alice_schedule"
```

The solver will stop at `t=5` and call the function `() -> interact(alice)` (a closure is taken at the time when `@future` is invoked). This interaction is identified as `"alice_schedule"`.

# Control Interactions
You may schedule control function calls, to be executed at every step of the model.
An action is modeled as a tuple `(id, call)`, where `id` is an optional textual identifier of the action, and `call` is a (parameterless) anonymous function.
Once the action is executed, the return value with corresponding action id and execution time is added to `controls_log` field of `Opera` instance.

See [`add_control!`](@ref) and [`@control`](@ref).

## Example

```julia
system = MyAgentType("system")
control = agent -> agent.temp > 100 && cool!(agent)
@control system control(system) "temperature control"
```

At each step, the solver will call the function `() -> control(system)` (a closure is taken at the time when `@future` is invoked).

# Instantious Interactions
You may schedule additional interactions which exist within a single step of the model;
such actions are modeled as named tuples `(id, priority=0., call)`. Here, `call` is a (parameterless) anonymous function.

They exist within a single step of the model and are executed after the calls
to `_prestep!` and `_step!` finish, in the order of the assigned priorities.

In particular, you may schedule interactions of two kinds:
 
 - `poke(agent, priority)`, which will translate into a call `() -> _interact!(agent)`, with the specified priority,
 - `@call opera expresion priority`, which will translate into a call `() -> expression`, with the specified priority.

See [`poke`](@ref) and [`@call`](@ref).

## Examples

```julia
# `poke`
poke(agent, 1.) # call `_interact!(agent)`; this call is added to the instantious priority queue with priority 1
```

```julia
# `@call`
bob_agent = only(getagent(agent, r"bob"))
@call agent wake_up(bob_agent) # translates into `() -> wake_up(bob_agent)` with priority 0
```
"""
mutable struct Opera
    # dictionary of `uuid => agent` pairs
    directory::Dict{UUID, AbstractAlgebraicAgent}
    # intantious interactions
    instantious_interactions::Vector{InstantiousInteraction}
    instantious_interactions_log::Vector{InstantiousInteractionLog}
    n_instantious_interactions::Ref{UInt}
    # futures
    futures::Vector{Future}
    futures_log::Vector{FutureLog}
    n_futures::Ref{UInt}
    # controls
    controls::Vector{Control}
    controls_log::Vector{ControlLog}
    n_controls::Ref{UInt}

    function Opera(uuid2agent_pairs...)
        new(Dict{UUID, AbstractAlgebraicAgent}(uuid2agent_pairs...),
            Vector{InstantiousInteraction}(undef, 0),
            Vector{InstantiousInteractionLog}(undef, 0),
            0,
            Vector{Future}(undef, 0),
            Vector{FutureLog}(undef, 0),
            0,
            Vector{Control}(undef, 0),
            Vector{ControlLog}(undef, 0),
            0,)
    end
end

# increase the count the number of anonymous interactions of the given count,
# and return the count
function get_count(opera::Opera, type::Symbol)
    (getproperty(opera, type)[] += 1) |> string
end

# dispatch on the interaction call, and execute it
function call(opera::Opera, call::Function)
    if hasmethod(call, Tuple{})
        call()
    elseif hasmethod(call, Tuple{Opera})
        call(opera)
    elseif length(opera.directory) > 1 &&
           hasmethod(call, Tuple{typeof(topmost(first(opera.directory)[2]))})
        call(topmost(first(opera.directory)[2]))
    else
        @error """interaction $call must have one of the following forms:
            - be parameterless,
            - be a function of `Opera` instance,
            - be a function of the topmost agent in the hierarchy.
        """
    end
end

"""
    add_instantious!(opera, call, priority=0[, id])
    add_instantious!(agent, call, priority=0[, id])
Schedule a `call` to be executed in the current time step.

Interactions are implemented within an instance `Opera`, sorted by their priorities.

See also [`Opera`](@ref).

# Examples
```julia
add_instantious!(agent, () -> wake_up(agent))
```
"""
function add_instantious!(opera::Opera, call, priority::Number = 0.0,
    id = "instantious_" *
         get_count(opera, :n_instantious_interactions))
    add_instantious!(opera, (; id, call, priority))
end

function add_instantious!(agent::AbstractAlgebraicAgent, args...)
    add_instantious!(getopera(agent), args...)
end

function add_instantious!(opera::Opera, action::InstantiousInteraction)
    # sorted insert
    insert_at = searchsortedfirst(opera.instantious_interactions, action;
        by = x -> x.priority)
    insert!(opera.instantious_interactions, insert_at, action)
end

# Execute instantious interactions
function execute_instantious_interactions!(opera::Opera, time)
    while !isempty(opera.instantious_interactions)
        action = pop!(opera.instantious_interactions)
        log_record = (; id = action.id, time, retval = call(opera, action.call))

        push!(opera.instantious_interactions_log, log_record)
    end
end

"""
    poke(agent, priority=0[, id])
Poke an agent in the current time step. Translates to a call `() -> _interact(agent)`, see [`@call`](@ref).

Interactions are implemented within an instance `Opera`, sorted by their priorities.

See also [`Opera`](@ref).

# Examples
```julia
poke(agent)
poke(agent, 1.) # with priority equal to 1
```
"""
function poke(agent, priority::Number = 0.0,
    id = "instantious_" * get_count(getopera(agent), :n_instantious_interactions))
    add_instantious!(getopera(agent),
        (; id, call = () -> _interact!(agent),
            priority = Float64(priority)))
end

"""
    @call agent call [priority[, id]]
    @call opera call [priority[, id]]
Schedule an interaction (call), which will be executed in the current time step.
Here, `call` will translate into a function `() -> call`.

Interactions are implemented within an instance `Opera`, sorted by their priorities.

See also [`Opera`](@ref).

# Examples
```julia
bob_agent = only(getagent(agent, r"bob"))
@call agent wake_up(bob_agent) # translates into `() -> wake_up(bob_agent)`
```
"""
macro call(opera, call, priority::Number = 0.0, id = nothing)
    quote
        opera = $(esc(opera)) isa Opera ? $(esc(opera)) : getopera($(esc(opera)))
        id = if isnothing($(esc(id)))
            "instantious_" * get_count(opera, :n_instantious_interactions)
        else
            $(esc(id))
        end

        add_instantious!(opera,
            (; id, call = () -> $(esc(call)),
                priority = Float64($(esc(priority)))))
    end
end

"""
    add_future!(opera, time, call[, id])
    add_future!(agent, time, call[, id])
Schedule a (delayed) execution of `call` at `time`. Optionally, provide a textual identifier `id` of the action.

Here, `call` has to follow either of the following forms:
    - be parameterless,
    - be a function of `Opera` instance,
    - be a function of the topmost agent in the hierarchy.
This follows the dynamic dispatch.

See also [`Opera`](@ref).

# Examples
```julia
alice = MyAgentType("alice")
interact = agent -> wake_up!(agent)
add_future!(alice, 5.0, () -> interact(alice), "alice_schedule")
```
"""
function add_future! end

function add_future!(opera::Opera, time, call,
    id = "future_" * get_count(opera, :n_futures))
    new_action = (; id, call, time)

    # sorted insert
    insert_at = searchsortedfirst(opera.futures, new_action, by = x -> x.time)
    insert!(opera.futures, insert_at, new_action)
end

function add_future!(agent::AbstractAlgebraicAgent, args...)
    add_future!(getopera(agent), args...)
end

"""
    @future opera time call [id]
    @future agent time call [id]
Schedule a (delayed) execution of `call` at `time`. Optionally, provide a textual identifier `id` of the action.

`call` is an expression, which will be wrapped into a function `() -> call` (taking closure at the time when `@future` is invoked).

See also [`@future`](@ref) and [`Opera`](@ref).

# Examples

```julia
alice = MyAgentType("alice")
interact = agent -> wake_up!(agent)
@future alice 5.0 interact(alice) "alice_schedule" # stop at `t=5`
```
"""
macro future(opera, time, call, id = nothing)
    quote
        opera = $(esc(opera)) isa Opera ? $(esc(opera)) : getopera($(esc(opera)))
        id = if isnothing($(esc(id)))
            "future_" * get_count(opera, :n_futures)
        else
            $(esc(id))
        end

        add_future!(opera, $(esc(time)), () -> $(esc(call)),
            id)
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
    add_control!(agent, call[, id])
Add a control to the system. Optionally, provide a textual identifier `id` of the action.

Here, `call` has to follow either of the following forms:
    - be parameterless,
    - be a function of `Opera` instance,
    - be a function of the topmost agent in the hierarchy.
This follows the dynamic dispatch.

See also [`@control`](@ref) and [`Opera`](@ref).

# Examples
```julia
system = MyAgentType("system")
control = agent -> agent.temp > 100 && cool!(agent)
add_control!(system, () -> control(system), "temperature control")
```
"""
function add_control! end

function add_control!(opera::Opera, call, id = "control_" * get_count(opera, :n_controls))
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

# Examples

```julia
system = MyAgentType("system")
control = agent -> agent.temp > 100 && cool!(agent)
@control system control(system) "temperature control"
```
"""
macro control(opera, call, id = nothing)
    quote
        opera = $(esc(opera)) isa Opera ? $(esc(opera)) : getopera($(esc(opera)))
        id = if isnothing($(esc(id)))
            id = "control_" * get_count(opera, :n_controls)
        else
            $(esc(id))
        end

        add_control!($(esc(opera)), () -> $(esc(call)), id)
    end
end

# execute system controls
function execute_controls!(opera::Opera, time)
    foreach(opera.controls) do action
        log_record = (; id = action.id, time, retval = call(opera, action.call))
        push!(opera.controls_log, log_record)
    end
end

# if `expr` is a string, parse it as an expression
function get_expr(expr)
    if expr isa AbstractString
        Base.eval(eval_scope, Meta.parseall(expr))
    else
        expr
    end
end

"""
    load_opera!(opera, dump; eval_scope=@__MODULE__)
Load interactions from a dictionary that contains the entries `instantious`, `futures`, and `controls`.
Each of these entries is a vector defining the respective interactions.

- `instantious` ([`InstantiousInteraction`](@ref)): specify `call` and, optionally, `priority=0` and `id`,
- `futures` ([`Future`](@ref)): specify `time`, `call`, and, optionally, `id`,
- `controls` ([`Control`](@ref)): specify `call` and, optionally, `id`.

# Example
```julia
system_dump = AlgebraicAgents.save(system)

opera_dump = Dict(
    "instantious" => [Dict("call" => () -> println("instantious interaction"))],
    "futures" => [Dict("time" => 2., "call" => () -> println("future"))],
    "controls" => [Dict("call" => () -> println("control"))]
)

push!(system_dump, "opera" => opera_dump)
```
"""
function load_opera!(opera::Opera, dump::AbstractDict; eval_scope=@__MODULE__)
    # instantious interactions
    for interaction in get(dump, "instantious", [])
        add_instantious!(opera,
            get_expr(interaction["call"]),
            get(interaction, "priority", 0),
            get(interaction, "id", "instantious_" * get_count(opera, :n_instantious_interactions))
        )
    end

    # futures
    for interaction in get(dump, "futures", [])
        add_future!(opera,
            interaction["time"],
            get_expr(interaction["call"]),
            get(interaction, "id", "future_" * get_count(opera, :n_futures))
        )
    end

    # controls
    for interaction in get(dump, "controls", [])
        add_control!(opera,
            get_expr(interaction["call"]),
            get(interaction, "id", "control_" * get_count(opera, :n_controls))
        )
    end

    return opera
end