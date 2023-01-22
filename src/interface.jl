## algebraic agent types

"""
A container of algebraic agents.
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
    Initialize an algebraic agent. Optionally provide contained agents at the time of instantiation.
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
Get algebraic agent's name.
"""
getname(a::AbstractAlgebraicAgent) = a.name

"""
    getuuid(agent)
Get algebraic agent's uuid.
"""
getuuid(a::AbstractAlgebraicAgent) = a.uuid

"""
    getparent(agent)
Get algebraic agent's parent.
"""
getparent(a::AbstractAlgebraicAgent) = a.parent

"""
    setparent!(agent, parent)
Set algebraic agent's parent.
"""
function setparent!(a::AbstractAlgebraicAgent, p::Union{AbstractAlgebraicAgent, Nothing})
    !isnothing(getparent(a)) && pop!(inners(getparent(a)), getname(a))
    a.parent = p
end

"""
    inners(agent)
Get dictionary of algebraic agent's inner agents. Follows `name => agent` format.
"""
inners(a::AbstractAlgebraicAgent) = a.inners #@error "algebraic agent type $(typeof(a)) doesn't implement inner agents!"

"""
    getparameters(agent)
Retrieve algebraic agents' (incl. inner agents, if applicable) parameter space.
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
Retrieve parameter space of an algebraic agent.
"""
_getparameters(::AbstractAlgebraicAgent) = nothing

"""
    _setparameters!
Mutate algebraic agent's parameter space.

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
        @error("type $(typeof(a)) doesn't implement `_setparameters!`")
    end

    params
end

"""
    setparameters!(agent, parameters)

Assign algebraic agent's parameters.
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
Solves an (initialized) algebraic problem. 
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

Performs a single evolutionary step of the algebraic hierarchy.
To avoid frontrunning, solutions will be projected only up to time `t``.
This is a two-phase step; the corresponding stepping functions are `_prestep!` and `step!`.

More particular behavior can be implemented using [`Opera`](@ref) protocol.

For custom algebraic agents' types, it suffices to implement [`_step!`](@ref).

# Return values
Return `true` if all internal algebraic agent's time horizon was reached.
Else return the minimum time up to which the algebraic agent's solution was projected.
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

    isroot && opera_run!(getopera(a))

    ret
end

"""
    projected_to(agent)
Return `true` if all algebraic agent's time horizon was reached (or `nothing` in case of delegated evolution).
Else return the minimum time up to which the evolution of an algebraic agent, and all its descendants, has been projected.
"""
function projected_to(a::AbstractAlgebraicAgent)
    ret = _projected_to(a)
    foreach(values(inners(a))) do a
        @ret ret projected_to(a)
    end

    ret
end

"Return time to which algebraic agent's evolution was projected."
function _projected_to(t::AbstractAlgebraicAgent)
    @error("type $(typeof(t)) doesn't implement `_projected_to`")
end
_projected_to(::FreeAgent) = nothing

"Project algebraic agent's solution up to time `t`."
function _step!(a::AbstractAlgebraicAgent)
    @error "algebraic agent $(typeof(a)) doesn't implement `_step!`"
end
_step!(::FreeAgent) = nothing

"Pre-step to a step call (e.g., projecting algebraic agent's solution up to time `t`)."
_prestep!(::AbstractAlgebraicAgent, _) = nothing

"Wake up an agent. See [`Opera`](@ref)."
_interact!(::AbstractAlgebraicAgent) = nothing

"""
    reinit!(agent)
Reinitialize state of algebraic agents hierarchy.

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

"Reinitialize the state of an algebraic agent."
_reinit!(::AbstractAlgebraicAgent) = nothing

"""
    getobservable(agent, args...)
Get algebraic agent's observable.

# Examples
```julia
getobservable(getagent(agent, "../model"), "observable_name")
getobservable(getagent(agent, "../model"), 1)
```
"""
function getobservable(a::AbstractAlgebraicAgent, args...)
    @error "algebraic agent $(typeof(a)) doesn't implement `getobservable`"
end

# implement `a[observable]` syntax
function Base.getindex(a::AbstractAlgebraicAgent, keys...)
    if isempty(keys)
        a
    else
        getobservable(a, keys...)
    end
end

"Get algebraic agent's observable at a given time."
function gettimeobservable(a::AbstractAlgebraicAgent, ::Number, ::Any)
    @error "algebraic agent $(typeof(a)) doesn't implement `gettimeobservable`"
end

"Return a list of algebraic agent's inner ports (subjective observables)."
ports_in(::AbstractAlgebraicAgent) = nothing

"Return a list of algebraic agent's outer ports (objective observables)."
exposed_ports(::AbstractAlgebraicAgent) = nothing

"Get algebraic agent's [`Opera`](@ref)."
getopera(a::AbstractAlgebraicAgent) = a.opera

"Get algebraic agent's directory. See also [`Opera`](@ref)."
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

"Pretty-print algebraic agent's header: name, uuid, and type. Optionally specify indent."
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

"Pretty-print algebraic agent's parent and inners. Optionally specify indent."
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

"Pretty-print custom fields of an algebraic agent."
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

#function Base.print(io::IO, a::AbstractAlgebraicAgent)
#    indent = get(io, :indent, 0)
#    print(io, " "^indent * "$(typeof(a)){name=$(getname(a)), uuid=$(string(getuuid(a))[1:8]), parent=$(getparent(a))}")
#end

"Plot an algebraic agent's state. For internal implementation, see [`_draw`](@ref)."
function draw end

"""
    draw(agent, path=".", args...; kwargs...)
Retrieve an agent from its relative path, and plot its state.
Reduces to [`_draw`](@ref).
"""
function draw(a::AbstractAlgebraicAgent, path = ".", args...; kwargs...)
    _draw(getagent(a, path), args...; kwargs...)
end

"Return plot of an algebraic agent's state. Defaults to `nothing`."
function _draw(a::AbstractAlgebraicAgent)
    @warn "`_draw` for algebraic agent type $(typeof(a)) not implemented"
end
