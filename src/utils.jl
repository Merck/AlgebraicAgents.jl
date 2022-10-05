"""
    @wrap(expr[, agent=:agent])

Turn `expr` into a function of `agent`, optionally specifying `agent` alias.

# Examples
```julia
@wrap agent
@wrap ag ag
```
"""
macro wrap(expr, agent=:agent)
    quote
        function (tlagent, agent)
            let $agent=agent
                $expr
            end
        end
    end
end

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
    add_integration(name)

Instantiate a package integration and add it to Julia's load path.

# Available integrations
 - `SciMLIntegration`
 - `AgentsIntegration`
"""
function add_integration(integration)
    integration_path = joinpath(dirname(pathof(AlgebraicAgents)), "integrations", string(integration))
    
    current_project = Pkg.project().path # get current project
    Pkg.activate(integration_path); Pkg.instantiate() # instantiate the integration
    Pkg.activate(current_project) # switch to top-level project
    
    union!(LOAD_PATH, (integration_path,)) # add the integration to package registries

    nothing
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
        set_parameters!(reinit!(agent), params)

        simulate(agent, max_t)
    end
end

"""
    @plot_df df t_ix=1
A macro to turn a DataFrame into a plot, taking `t_ix` as the time column.
"""
macro plot_df(df, t_ix=1)
    quote
        Base.require($(__module__), :DataFrames)
        data = Matrix($(esc(df))); t_ix = $(esc(t_ix))
        t = @view data[:, t_ix]; data_ = @view data[:, setdiff(1:size(data, 2), (t_ix,))]
        colnames = reshape($(esc(:(DataFrames.names)))($(esc(df)))[setdiff(1:size(data, 2), (t_ix,))], 1, :)
    
        Base.require($(__module__), :Plots)
        $(esc(:(Plots.plot)))(t, data_, labels=colnames, xlabel="t")
    end
end

"""
    @draw_df T field
A macro to define `_draw(T)` such that it will plot a DataFrame stored under `field`.

# Examples
```julia
@draw_df type field
```
"""
macro draw_df(T, field)
    quote 
        function AlgebraicAgents._draw(a::$T)
            df = getproperty(a, $(QuoteNode(field)))
            AlgebraicAgents.@plot_df df
        end
    end |> esc
end