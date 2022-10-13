"Return code propagation."
macro ret(old, ret)
    quote
        ret = $(esc(ret)); old = $(esc(old))
        val = if isnothing(ret) old
        elseif isnothing(old) ret
        elseif !isa(ret, Bool) && !isa(old, Bool)
            min(old, ret)
        else old end
        
        $(esc(old)) = val
    end
end

iscontinuable(ret) = !isnothing(ret) && (ret !== true)

"Turns aargs into a uuid-indexed dict."
function yield_aargs(a::AbstractAlgebraicAgent, aargs...)
    naargs = Dict{UUID, Tuple}()
    for (path, aarg) in aargs
        uuid_ = uuid(getagent(a, path))
        
        push!(naargs, uuid_ => (args=get(aarg, :args, ()), kwargs=get(aarg, :kwargs, ())))
    end

    naargs
end

"
    @schedule agent priority=0
Schedule an interaction. Interactions are implemented within an instance `Opera`, sorted by their priorities.
Internally, reduces to `_interact!(agent)`.

See also [`Opera`](@ref).

# Examples
```julia
@schedule agent 1.
```
"
macro schedule(agent, priority=0)
    quote
        opera_enqueue!(getopera($(esc(agent))), AgentCall($(esc(agent))), Float64($(esc(priority))))
    end  
end

"
    @schedule agent call priority=0
Schedule an interaction (call). Interactions are implemented within an instance `Opera`, sorted by their priorities.
Internally, the `call=f(args...)` expression will be transformed to an anonymous function `agent -> f(agent, args...)`.

See also [`Opera`](@ref).

# Examples
```julia
@schedule agent f(t)
```
"
macro schedule_call(agent, call, priority=0)
    call = if call isa Expr && Meta.isexpr(call, :call)
            sym = gensym(); insert!(call.args, 2, sym)
            :($sym -> $(call))
        else call end

    quote
        opera_enqueue!(getopera($(esc(agent))), AgentCall($(esc(agent)), $(esc(call))), Float64($(esc(priority))))
    end
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
    obs = Expr(:vcat); for arg in args
        if arg isa Expr && Meta.isexpr(arg, :call) && (arg.args[1] == :(:))
            agent_ = arg.args[2]; obs_name = arg.args[3]

            if obs_name isa Expr && (obs_name.head ∈ [:vect, :tuple])
                for name in obs_name.args
                    push!(obs.args, :(getobservable(getagent($(esc(agent)), $(esc(agent_))), $(esc(name)))))
                end
            else push!(obs.args, :(getobservable(getagent($(esc(agent)), $(esc(agent_))), $(esc(obs_name))))) end
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
    dir = getdirectory(a); flat_repr = Dict{String, AbstractAlgebraicAgent}()
    for (p, v) in relpathrefs(a)
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
function objective(agent::AbstractAlgebraicAgent, max_t=Inf)
    function (params)
        setparameters!(reinit!(agent), params)

        simulate(agent, max_t)
    end
end

"""
Specialize the function to support convenience wrap initialization, dispatched on the arguments' types.
See [`@wrap`](@ref). 
"""
_construct_agent(::AbstractString, args...) = @error "`_construct_agent` for type $(typeof(args[1])) not defined"

"Return a vector of arg and kwargs expression in `args`, respectively."
function args_kwargs(args)
    filtered_args = Any[]; filtered_kwargs = Any[]
    map(args) do x
        if isexpr(x, :(=))
            push!(filtered_kwargs, Expr(:kw, x.args[1], x.args[2]))
        else push!(filtered_args, x) end
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