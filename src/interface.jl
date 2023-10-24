## agent types

"""
A container of agents.
Doesn't implement a standalone evolutionary rule; delegates evolution to internal agents.
"""
mutable struct FreeAgent <: AbstractAlgebraicAgent
    uuid::UUID
    name::AbstractString

    parent::Union{AbstractAlgebraicAgent, Nothing}
    inners::Dict{String, AbstractAlgebraicAgent}

    relpathrefs::Dict{AbstractString, UUID}
    opera::Opera

    @doc """
        FreeAgent(name, agents=[])
    Initialize an agent. Optionally provide contained agents at the time of instantiation.
    See also [`entangle!`](@ref) and [`disentangle!`](@ref).

    # Examples 
    ```julia
    FreeAgent("agent", [agent1, agent2])
    ```
    """
    function FreeAgent(name::AbstractString,
        agents::Vector{<:AbstractAlgebraicAgent} = AbstractAlgebraicAgent[])
        m = new()
        m.uuid = uuid4()
        m.name = name
        m.parent = nothing
        m.inners = Dict{String, AbstractAlgebraicAgent}()
        m.relpathrefs = Dict{AbstractString, UUID}()
        m.opera = Opera(m.uuid => m)

        for a in agents
            entangle!(m, a)
        end

        m
    end
end

## implements interface

"""
    getname(agent)
Get agent's name.
"""
getname(a::AbstractAlgebraicAgent) = a.name

"""
    getuuid(agent)
Get agent's uuid.
"""
getuuid(a::AbstractAlgebraicAgent) = a.uuid

"""
    getparent(agent)
Get agent's parent.
"""
getparent(a::AbstractAlgebraicAgent) = a.parent

"""
    setparent!(agent, parent)
Set agent's parent.
"""
function setparent!(a::AbstractAlgebraicAgent, p::Union{AbstractAlgebraicAgent, Nothing})
    !isnothing(getparent(a)) && pop!(inners(getparent(a)), getname(a))
    a.parent = p
end

"""
    inners(agent)
Get dictionary of agent's inner agents. Follows `name => agent` format.
"""
inners(a::AbstractAlgebraicAgent) = a.inners #@error "agent type $(typeof(a)) doesn't implement inner agents!"

"""
    getparameters(agent)
Retrieve agents' (incl. inner agents, if applicable) parameter space.
"""
function getparameters(a::AbstractAlgebraicAgent, path = ".", dict = Dict{String, Any}())
    params = _getparameters(a)
    !isnothing(params) && push!(dict, path => params)

    for a in values(inners(a))
        getparameters(a, normpath(joinpath(path, getname(a), ".")), dict)
    end

    dict
end

"""
    _getparameters(agent)
Retrieve parameter space of an agent.
"""
_getparameters(::AbstractAlgebraicAgent) = nothing

"""
    _setparameters!
Mutate agent's parameter space.

# Examples
```julia
_setparameters!(agent, Dict(:α=>1))
_setparameters!(agent, [1., 2.])
```
"""
function _setparameters!(a::AbstractAlgebraicAgent, parameters)
    params = _getparameters(a)
    if params isa Dict
        merge!(params, parameters)
    elseif params isa AbstractArray
        params .= parameters
    else
        error("type $(typeof(a)) doesn't implement `_setparameters!`")
    end

    params
end

"""
    setparameters!(agent, parameters)
Assign agent's parameters.
Parameters are accepted in the form of a dictionary containing `path => params` pairs.

# Examples
```julia
setparameters!(agent, Dict("agent1/agent2" => Dict(:α=>1)))
```
"""
function setparameters!(a::AbstractAlgebraicAgent, parameters, path = ".")
    if haskey(parameters, path)
        _setparameters!(a, parameters[path])
    end

    for a in values(inners(a))
        setparameters!(a, parameters, normpath(joinpath(path, getname(a), ".")))
    end

    a
end

"""
    simulate(agent::AbstractAlgebraicAgent, max_t=Inf)::AbstractAlgebraicAgent
Solves an (initialized) problem. 
Runs a loop until all the agents return `true` (reached simulation horizon) or `nothing` (delegated evolution),
or until the simulation horizon reaches `max_t`.
Avoids front-running.

# Examples
```julia
sol = simulate(model)
```
"""
function simulate(a::AbstractAlgebraicAgent, max_t = Inf)
    ret = projected_to(a)
    while iscontinuable(ret) && (ret < max_t)
        ret = step!(a)
    end

    a
end

"""
    step!(agent, t=projected_to(agent))
Performs a single evolutionary step of the hierarchy.
To avoid frontrunning, solutions will be projected only up to time `t`.
This is a two-phase step; the corresponding stepping functions are `_prestep!` and `step!`.

More particular behavior can be implemented using [`Opera`](@ref) protocol.

For custom agents' types, it suffices to implement [`_step!`](@ref).

# Return values
Return `true` if all internal agent's time horizon was reached.
Else return the minimum time up to which the agent's solution was projected.
"""
function step!(a::AbstractAlgebraicAgent, t = projected_to(a); isroot = true)
    isroot && prewalk(a -> _prestep!(a, t), a) # first phase

    # first into the depth
    ret = nothing
    foreach(values(inners(a))) do a
        @ret ret step!(a, t; isroot = false)
    end

    # local step implementation
    if (p = _projected_to(a); !isa(p, Bool) && (p == t))
        _step!(a)
    end
    @ret ret _projected_to(a)

    if isroot
        execute_instantious_interactions!(getopera(a), t)
        @ret ret execute_futures!(getopera(a), t)
        execute_controls!(getopera(a), t)
    end

    ret
end

"""
    projected_to(agent)
Return `true` if all agent's time horizon was reached (or `nothing` in case of delegated evolution).
Else return the minimum time up to which the evolution of an agent, and all its descendants, has been projected.
"""
function projected_to(a::AbstractAlgebraicAgent; isroot = true)
    ret = _projected_to(a)
    foreach(values(inners(a))) do a
        @ret ret projected_to(a; isroot = false)
    end

    if isroot
        foreach(getopera(a).futures) do i
            @ret ret i.time
        end
    end

    ret
end

"Return time to which agent's evolution was projected."
function _projected_to(t::AbstractAlgebraicAgent)
    error("type $(typeof(t)) doesn't implement `_projected_to`")
end

_projected_to(::FreeAgent) = nothing

"Step an agent forward (call only if its projected time is equal to the least projected time, among all agents in the hierarchy)."
function _step!(a::AbstractAlgebraicAgent)
    @error "agent $(typeof(a)) doesn't implement `_step!`"
end
_step!(::FreeAgent) = nothing

"Pre-step to a step call (e.g., projecting agent's solution up to time `t`)."
_prestep!(::AbstractAlgebraicAgent, _) = nothing

"Wake up an agent. See [`Opera`](@ref)."
_interact!(::AbstractAlgebraicAgent) = nothing

"""
    reinit!(agent)
Reinitialize state of agents hierarchy.

# Examples
```julia
reinit!(agent)
```
"""
function reinit!(a::AbstractAlgebraicAgent)
    _reinit!(a)
    for a in values(inners(a))
        reinit!(a)
    end

    a
end

"Reinitialize the state of an agent."
_reinit!(::AbstractAlgebraicAgent) = nothing

"""
    getindex(agent, keys...)
Get inner agents of an agent using a convenient syntax.
# Examples
```julia
myagent = FreeAgent("root", [FreeAgent("a"),FreeAgent("b")])
myagent["a"]
myagent[["a","b"]]
myagent[:]
```
"""

Base.getindex(a::AbstractAlgebraicAgent, key::AbstractString) = getindex(inners(a), key)
function Base.getindex(a::AbstractAlgebraicAgent, I::AbstractVector{<:AbstractString})
    getindex.(Ref(inners(a)), [I...])
end
Base.getindex(a::AbstractAlgebraicAgent, ::Colon) = collect(values(inners(a)))
function Base.getindex(::AbstractAlgebraicAgent, args...)
    throw(ArgumentError("invalid index: $(args) of type $(typeof(args))"))
end

"""
    getobservable(agent, args...)
Get agent's observable.

# Examples
```julia
getobservable(getagent(agent, "../model"), "observable_name")
getobservable(getagent(agent, "../model"), 1)
```
"""
function getobservable(a::AbstractAlgebraicAgent, args...)
    @error "agent $(typeof(a)) doesn't implement `getobservable`"
end

"Get agent's observable at a given time."
function gettimeobservable(a::AbstractAlgebraicAgent, ::Number, ::Any)
    @error "agent $(typeof(a)) doesn't implement `gettimeobservable`"
end

"""
    observables(agent)
Return a list of observables (explicitly) exported by an agent. Use [`getobservable`](@ref) to retrieve the observable's value.
"""
function observables(a::AbstractAlgebraicAgent)
    @error "agent $(typeof(a)) doesn't implement `observables`"
end

"Get agent's [`Opera`](@ref)."
getopera(a::AbstractAlgebraicAgent) = a.opera

"Get agent's directory. See also [`Opera`](@ref)."
getdirectory(a::AbstractAlgebraicAgent) = getopera(a).directory

"Let `a`'s Opera refer to `o`."
function sync_opera!(a::AbstractAlgebraicAgent, o::Opera)
    for k in propertynames(o)
        setproperty!(getopera(a), k, getproperty(o, k))
    end

    a
end

"Return relative path to uuid map."
relpathrefs(a::AbstractAlgebraicAgent) = a.relpathrefs

"Pretty-print agent's header: name, uuid, and type. Optionally specify indent."
function print_header end

function print_header(io::IO, ::MIME"text/plain", a::AbstractAlgebraicAgent)
    indent = get(io, :indent, 0)

    print(io, " "^indent, "agent ", crayon"bold green", getname(a), " ", crayon"reset")
    print(io, "with uuid ", crayon"green", string(getuuid(a))[1:8], " ", crayon"reset")
    print(io, "of type ", crayon"green", typeof(a), " ", crayon"reset")
end

function print_header(io::IO, a::AbstractAlgebraicAgent)
    indent = get(io, :indent, 0)
    print(io,
        " "^indent *
        "$(typeof(a)){name=$(getname(a)), uuid=$(string(getuuid(a))[1:8]), parent=$(getparent(a))}")
end

"Pretty-print agent's parent and inners. Optionally specify indent."
function print_neighbors(io::IO, m::MIME"text/plain", a::AbstractAlgebraicAgent,
    expand_inners = true)
    indent = get(io, :indent, 0)

    expand_inners && !isnothing(getparent(a)) &&
        print(io, "\n", " "^(indent + 3), crayon"bold", "parent: ", crayon"reset",
            crayon"green", getname(getparent(a)), crayon"reset")
    !isempty(values(inners(a))) &&
        print(io, "\n", " "^(indent + 3), crayon"bold", "inner agents: ", crayon"reset")

    max_inners = get(io, :max_list_length, 5)
    if expand_inners
        iio = IOContext(io, :indent => get(io, :indent, 0) + 4)
        for a in first(values(inners(a)), max_inners)
            print(io, "\n")
            show(iio, m, a, false)
        end
        (length(inners(a)) > max_inners) && print(io,
            "\n" * " "^(indent + 4) *
            "$(length(inners(a))-max_inners) more agent(s) not shown ...")
    else
        print(io, join([getname(a) for a in values(inners(a))], ", "))
    end
end

"Pretty-print custom fields of an agent."
function print_custom(io::IO, mime::MIME"text/plain", a::AbstractAlgebraicAgent)
    extra_fields = setdiff(propertynames(a), fieldnames(FreeAgent))
    indent = get(io, :indent, 0)

    isempty(extra_fields) && return

    print(io, "\n", " "^(indent + 3), "custom properties:")
    for field in extra_fields
        print(io, "\n", " "^(indent + 3), AlgebraicAgents.crayon"italics", field, ": ",
            AlgebraicAgents.crayon"reset", getproperty(a, field))
    end
end

# specialize show method
function Base.show(io::IO, m::MIME"text/plain", a::AbstractAlgebraicAgent,
    expand_inners = true)
    print_header(io, m, a)
    print_custom(io, m, a)
    print_neighbors(io, m, a, expand_inners)
end

Base.show(io::IO, a::AbstractAlgebraicAgent) = print_header(io, a)

"Plot an agent's state. For internal implementation, see [`_draw`](@ref)."
function draw end

"""
    draw(agent, path=".", args...; kwargs...)
Retrieve an agent from its relative path, and plot its state.
Reduces to [`_draw`](@ref).
"""
function draw(a::AbstractAlgebraicAgent, path = ".", args...; kwargs...)
    _draw(getagent(a, path), args...; kwargs...)
end

"Return plot of an agent's state. Defaults to `nothing`."
function _draw(a::AbstractAlgebraicAgent)
    @warn "`_draw` for agent type $(typeof(a)) not implemented"
end

"""
    load(hierarchy; eval_scope=Main)
Instantiate an agent hierarchy from a dictionary.

By default, each agent is represented as a dictionary with fields
- `type`: type of the agent, this can be a string containing the type name or the actual type,
- `name`: name of the agent,
- `arguments` (unless empty): a vector of agent's properties, excluding common interface properties (such as `name`, `uuid`, `parent`, `opera`, etc.)
- `inners` (unless empty): a vector with inner agents' representations.

For example,
```julia
Dict(
    "type" => FreeAgent, "name" => "system", 
    "inners" => [
        Dict("name" => "alice", "type" => MyAgent{Float64}, "arguments" => Any[0.0, 1.0]),
        Dict("name" => "bob", "type" => MyAgent{Float64}, "arguments" => Any[0.0, 1.5]),
    ]
)
```

Internally, the method retrieves the type of the encapsulating agent from the provided `hierarchy` dictionary and then calls `_load(type, hierarchy; eval_scope)` on it.
This process instantiates the encapsulating agent as well as all the associated inner agents contained within the `hierarchy`.

See also [`load`](@ref).
"""
function load(hierarchy::AbstractDict; eval_scope = Main)
    type = if hierarchy["type"] isa Type
        hierarchy["type"]
    else
        # convert the type name into the actual type for further processing
        Base.eval(eval_scope, Meta.parse(hierarchy["type"]))
    end

    return _load(type, hierarchy; eval_scope)
end

"""
    _load(type, hierarchy; eval_scope=@__MODULE__)
This is a low-level method used for instantiating an agent of the specified `type`. It also instantiates all the inner sub-agents found within the given `hierarchy` dictionary. 
"""
function _load(type::Type{T},
    hierarchy::AbstractDict;
    eval_scope = @__MODULE__) where {T <: AbstractAlgebraicAgent}
    agent = type(hierarchy["name"],
        get(hierarchy, "arguments", [])...;
        get(hierarchy, "keyword_arguments", [])...)
    foreach(i -> entangle!(agent, load(i; eval_scope)), get(hierarchy, "inners", []))

    # load interactions into Opera
    haskey(hierarchy, "opera") &&
        load_opera!(getopera(agent), hierarchy["opera"]; eval_scope)

    agent
end

"""
    save(agent)
Save an agent hierarchy into a dictionary.

By default, each agent is represented as a dictionary with fields
- `type`: type of the agent,
- `name`: name of the agent,
- `arguments` (unless empty): a vector of agent's properties, excluding common interface properties (such as `name`, `uuid`, `parent`, `opera`, etc.)
- `inners` (unless empty): a vector with inner agents' representations.

See also [`load`](@ref).

# Example
```julia
dump = save(agent)

# output
Dict(
    "type" => FreeAgent, "name" => "system", 
    "inners" => [
        Dict("name" => "alice", "type" => MyAgent{Float64}, "arguments" => Any[0.0, 1.0]),
        Dict("name" => "bob", "type" => MyAgent{Float64}, "arguments" => Any[0.0, 1.5]),
    ]
)
```
"""
function save(agent::AbstractAlgebraicAgent)
    extra_fields = [getproperty(agent, p)
                    for p in setdiff(propertynames(agent), common_interface_fields)]

    if isempty(extra_fields)
        agent_args = Dict("type" => typeof(agent), "name" => getname(agent))
    else
        agent_args = Dict("type" => typeof(agent),
            "name" => getname(agent),
            "arguments" => extra_fields)
    end

    if isempty(inners(agent))
        return agent_args
    else
        return merge(agent_args,
            Dict("inners" => map(i -> save(i), values(inners(agent)))))
    end
end
