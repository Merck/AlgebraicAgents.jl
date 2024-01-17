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

iscontinuable(ret) = !isnothing(ret) && !isa(ret, Bool)

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
    flatten(root_agent)
Return flat representation of agents' hierarchy.
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
    wrap_system(name, system, args...; kwargs...)
Typically, the function will dispatch on the type of `system` and initialise an algebraic agent which wraps the core dynamical system.
This allows you to specify the core dynamics directly using a third-party package syntax and hide the internals on this package's side from the user.

For instance, you may define a method `wrap_system(name, prob::DiffEqBase.DEProblem)`, which internally will invoke the constructor of `DiffEqAgent`.

# Examples
```julia
wrap_system("ode_agent", ODEProblem(f, u0, tspan))
wrap_system("abm_agent", ABM(agent, space; properties))
```
"""
function wrap_system end

"""
    extract_agent
Extract an agent from as a property of the dynamical system (wrapped by the agent).

# Examples
```julia
agent = extract_agent(params) # for SciML integration
agent = extract_agent(model, agent) # for ABM integration
```
"""
function extract_agent end
### ? write an error msg? the method would need a signature then

# typetree
rem_module(T::Type, rem) = begin
    rem ? string((T).name.name) : string(T)
end

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
