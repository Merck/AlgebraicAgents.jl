using InteractiveUtils: subtypes

"Return code propagation."
macro ret(old, ret)
    quote
        ret = $(esc(ret))
        old = $(esc(old))
        val = if isnothing(old)
            ret
        elseif isnothing(ret)
            old
        elseif !isa(ret, Bool) && !isa(old, Bool)
            min(old, ret)
        elseif !isa(ret, Bool)
            ret
        else
            old
        end

        $(esc(old)) = val
    end
end

iscontinuable(ret) = !isnothing(ret) && (ret !== true)

"Turns aargs into a uuid-indexed dict."
function yield_aargs(a::AbstractAlgebraicAgent, aargs...)
    naargs = Dict{UUID, Tuple}()
    for (path, aarg) in aargs
        uuid_ = uuid(getagent(a, path))

        push!(naargs,
              uuid_ => (args = get(aarg, :args, ()), kwargs = get(aarg, :kwargs, ())))
    end

    naargs
end

"""
    @observables agent path:obs path:(obs1, obs2) path:[obs1, obs2]
Retrieve (a vector of) observables relative to `agent`.

# Examples
```julia
@observables agent "../agent":"o"
@observables agent "../agent":("o1", "o2")
```
"""
macro observables(agent, args...)
    obs = Expr(:vcat)
    for arg in args
        if arg isa Expr && Meta.isexpr(arg, :call) && (arg.args[1] == :(:))
            agent_ = arg.args[2]
            obs_name = arg.args[3]

            if obs_name isa Expr && (obs_name.head ∈ [:vect, :tuple])
                for name in obs_name.args
                    push!(obs.args,
                          :(getobservable(getagent($(esc(agent)), $(esc(agent_))),
                                          $(esc(name)))))
                end
            else
                push!(obs.args,
                      :(getobservable(getagent($(esc(agent)), $(esc(agent_))),
                                      $(esc(obs_name)))))
            end
        else
            push!(obs.args, :(getobservable(getagent($(esc(agent)), $(esc(arg))))))
        end
    end

    obs
end

"""
    flatten(root_agent)

Return flat representation of algebraic agents hierarchy.
"""
function flatten(a::AbstractAlgebraicAgent)
    dir = getdirectory(a)
    flat_repr = Dict{String, AbstractAlgebraicAgent}()
    for (p, v) in get_relpathrefs!(a)
        push!(flat_repr, p => dir[v])
    end

    flat_repr
end

"""
    objective(agent, max_t=Inf)
Return a function which takes a dictionary of agent parameters,
and outputs a corresponding solution.
Optionally specify simulation horizon `max_t`.

# Examples
```julia
o = objective(agent)
o(Dict("agent" => [1., 2.]))
```
"""
function objective(agent::AbstractAlgebraicAgent, max_t = Inf)
    function (params)
        setparameters!(reinit!(agent), params)

        simulate(agent, max_t)
    end
end

"""
Specialize the function to support convenience wrap initialization, dispatched on the arguments' types.
See [`@wrap`](@ref). 
"""
function _construct_agent(::AbstractString, args...)
    @error "`_construct_agent` for type $(typeof(args[1])) not defined"
end

"Return a vector of arg and kwargs expression in `args`, respectively."
function args_kwargs(args)
    filtered_args = Any[]
    filtered_kwargs = Any[]
    map(args) do x
        if Meta.isexpr(x, :(=))
            push!(filtered_kwargs, Expr(:kw, x.args[1], x.args[2]))
        else
            push!(filtered_args, x)
        end
    end

    filtered_args, filtered_kwargs
end

"""
    @wrap name args... kwargs...
A convenience macro to initialize an algebraic wrap, dispatched on the arguments' types.
See [`_construct_agent`](@ref).

# Examples
```julia
@wrap "ode_agent" prob ODEProblem(f, u0, tspan)
@wrap ode_agent prob ODEProblem(f, u0, tspan)
```
"""
macro wrap(name, fields...)
    args, kwargs = args_kwargs(fields)
    quote
        AlgebraicAgents._construct_agent($(string(name)), $(args...); $(kwargs...))
    end |> esc
end

"Extract algebraic wrap from `obj`."
_get_agent(obj, _...) = @error "`_get_agent` for type $(typeof(obj)) not implemented"

"""
    @get_agent obj
Extract algebraic wrap from `obj`.
Reduces to [`_get_agent`](@ref), as overloaded by third-party packages integrations.

# Examples
```julia
wrap = @get_agent params # for SciML integration
wrap = @get_agent model agent # for ABM integration
```
"""
macro get_agent(obj, args...)
    quote
        AlgebraicAgents._get_agent($obj, $(args...))
    end |> esc
end

# typetree
rem_module(T::Type, rem) = begin rem ? string((T).name.name) : string(T) end

"""
    typetree_mmd(T, TT; rem = false)
Return a `Vector{String}` of the type hierarchy with type `T`, in format suitable
for making [Mermaid](https://github.com/mermaid-js/mermaid) class diagrams. For
the root case (where `T` is the top of the hierarchy), `TT` may be set to nothing
(default argument).

The keyword argument `rem` can be set to true to strip the module prefix from typenames.
This is useful for Mermaid diagrams, because the Mermaid classDiagram does not
currently support "." characters in class names.

# Examples
```julia
# the following may be pasted into the Mermaid live editor:
# https://mermaid.live/
print(join(typetree_mmd(Integer), ""))
```
"""
function typetree_mmd(T::Type, TT::S = nothing;
                      rem = false) where {S <: Union{Type, Nothing}}
    ret = Vector{String}()
    if isnothing(TT)
        append!(ret, ["classDiagram\n"])
    end
    append!(ret, ["class $(rem_module(T, rem))\n"])
    if isabstracttype(T)
        append!(ret, ["<<Abstract>> $(rem_module(T, rem))\n"])
    end
    if !isnothing(TT)
        append!(ret, ["$(rem_module(TT, rem)) <|-- $(rem_module(T, rem))\n"])
    end
    sub_types = [i for i in subtypes(T)]
    for i in eachindex(sub_types)
        append!(ret, typetree_mmd(sub_types[i], T; rem))
    end
    ret
end

"""
    agent_hierarchy_mmd(a; use_uuid = 0)
This function can help display the agent hierarchy
for concrete models. It assumes the user wants to pass the results into a Mermaid
diagram for easier visualization of concrete model instantiations. The kwarg `use_uuid`
will append the last `use_uuid` digits of each agent to their name following an
underscore. This can be useful if it is not possible to distinguish unique agents
purely by their name alone.

# Examples
```julia
# the following may be pasted into the Mermaid live editor:
# https://mermaid.live/

@aagent FreeAgent struct AgentType1 end
base = FreeAgent("agent1")
entangle!(base, AgentType1("agent2"))
entangle!(base, AgentType1("agent3"))

# do not print UUIDs
hierarchy = agent_hierarchy_mmd(base)
print(join(hierarchy,""))

# print last 4 digits of UUIDs
hierarchy = agent_hierarchy_mmd(base, use_uuid = 4)
print(join(hierarchy,""))
```
"""
function agent_hierarchy_mmd(a::T; use_uuid::Int = 0) where {T <: AbstractAlgebraicAgent}
    hierarchy_mmd = prewalk_ret(a -> _agent_hierarchy_mmd(a; use_uuid), a)
    pushfirst!(hierarchy_mmd, "classDiagram\n")

    vcat(hierarchy_mmd...)
end

"""
    _agent_hierarchy_mmd(a; use_uuid = 0)
Intended to be used with `prewalk_ret`, this function can help display the agent hierarchy
for concrete models.

See [`agent_hierarchy_mmd`](@ref) for a convenience wrapper.
"""
function _agent_hierarchy_mmd(a::T; use_uuid::Int = 0) where {T <: AbstractAlgebraicAgent}
    ret = Vector{String}()

    a_name = getname(a)
    if use_uuid > 0
        a_name = a_name * "_" * string(getuuid(a).value)[(end - (use_uuid - 1)):end]
    end
    append!(ret, ["class $(a_name)\n"])
    append!(ret, ["<<$(rem_module(typeof(a),true))>> $(a_name)\n"])
    if !isnothing(getparent(a))
        a_par_name = getname(getparent(a))
        if use_uuid > 0
            a_par_name = a_par_name * "_" *
                         string(getuuid(getparent(a)).value)[(end - (use_uuid - 1)):end]
        end
        append!(ret, ["$(a_par_name) <|-- $(a_name)\n"])
    end
    return ret
end
