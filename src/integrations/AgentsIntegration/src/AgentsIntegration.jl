module AgentsIntegration

using AlgebraicAgents
import Agents
import DataFrames
import Plots

export ABMAgent, AAgent
export @get_oagent, @get_omodel, @o

# algebraic wrap for AgentBasedModel type
## algebraic agent types
@oagent ABMAgent begin
    abm::Agents.AgentBasedModel

    agent_step!; model_step! # evolutionary functions
    kwargs # kwargs propagated to `run!` (incl. `adata`, `mdata`)
    when; when_model # when to collect agents data, model data
    # true by default, and performs data collection at every step
    # if an `AbstractVector`, checks if `t ∈ when`; otherwise a function (model, t) -> ::Bool
    step_size # how far the step advances, either a float or a function (model, t) -> size::Float64
    
    tspan::NTuple{2, Float64} # solution horizon, defaults to `(0., Inf)`
    t::Float64

    abm0::Agents.AgentBasedModel
    t0::Float64

    df_agents::DataFrames.DataFrame
    df_model::DataFrames.DataFrame
end

## implement constructor
"""
    ABMAgent(name, abm; kwargs...)
Initialize `ABMAgent`, incl. hierarchy of ABM's agents.

Configure the evolutionary step, logging, and step size by keyword arguments below.

# Arguments
- `agent_step!`, `model_step!`: same meaning as in `Agents.step!`
- in general, any kwarg accepted by `Agents.run!`, incl. `adata`, `mdata`
- `when`, `when_model`: when to collect agents data, model data
    true by default, and performs data collection at every step
    if an `AbstractVector`, checks if `t ∈ when`; otherwise a function (model, t) -> ::Bool
- `step_size`: how far the step advances, either a float or a function (model, t) -> size::Float64
- `tspan`: solution horizon, defaults to `(0., Inf)`
"""
function ABMAgent(name::String, abm::Agents.AgentBasedModel; 
        agent_step! =Agents.dummystep, model_step! =Agents.dummystep,
        when=true, when_model=when, step_size=1.,
        tspan::NTuple{2, Float64}=(0., Inf), kwargs...
    )

    # initialize wrap
    i = ABMAgent(name)

    i.abm = abm
    i.agent_step! = agent_step!; i.model_step! = model_step!; i.kwargs = kwargs
    i.when = when; i.when_model = when_model
    i.step_size = step_size; i.tspan = tspan; i.t = tspan[1]
    
    i.df_agents = DataFrames.DataFrame(); i.df_model = DataFrames.DataFrame()

    i.abm.properties[:__oagent__] = i
    i.abm0 = deepcopy(i.abm)
    i.t0 = i.t

    # initialize contained agents
    for (id, _) in abm.agents
        AlgebraicAgents.entangle!(i, AAgent(string(id))) 
    end

    i
end

## implement common interface
function AlgebraicAgents._step!(a::ABMAgent, t)
    if AlgebraicAgents.projected_to(a) === t
        step_size = a.step_size isa Number ? a.step_size : a.step_size(a.abm, t)
        collect_agents = a.when isa AbstractVector ? (t ∈ a.when) : a.when isa Bool ? a.when : a.when(a.abm, t)
        collect_model = a.when_model isa AbstractVector ? (t ∈ a.when_model) : a.when isa Bool ? a.when : a.when_model(a.abm, t)

        df_agents, df_model = Agents.run!(a.abm, a.agent_step!, a.model_step!, 1; a.kwargs...)
        # append collected data
        ## df_agents
        if collect_agents && ("step" ∈ names(df_agents))
            if a.t == a.tspan[1]
                df_agents_0 = df_agents[df_agents.step .== .0, :]
                df_agents_0[!, :step] = convert.(Float64, df_agents_0[!, :step])
                df_agents_0[!, :step] .+= a.t
                append!(a.df_agents, df_agents_0)
            end
            df_agents = df_agents[df_agents.step .== 1., :]
            append!(a.df_agents, df_agents)
            a.df_agents[end-DataFrames.nrow(df_agents)+1:end, :step] .+= a.t + step_size - 1
        end
        ## df_model
        if collect_model && ("step" ∈ names(df_model))
            if a.t == a.tspan[1]
                df_model_0 = df_model[df_model.step .== .0, :]
                df_model_0[!, :step] = convert.(Float64, df_model_0[!, :step])
                df_model_0[!, :step] .+= a.t
                append!(a.df_model, df_model_0)
            end
            df_model = df_model[df_model.step .== 1., :]
            append!(a.df_model, df_model)
            a.df_model[end-DataFrames.nrow(df_model)+1:end, :step] .+= a.t + step_size - 1
        end

        a.t += step_size; (a.t >= a.tspan[2]) && return true
    end

    a.t
end

# if step is a float, need to retype the dataframe
function fix_float!(df, val)
    if eltype(df[!, :step]) <: Int && !isa(val, Int)
        df[!, :step] = convert.(Float64, df[!, :step])
    end
end

AlgebraicAgents._projected_to(a::ABMAgent)::Float64 = a.tspan[2] <= a.t ? true : a.t

function AlgebraicAgents.getobservable(a::ABMAgent, obs)
    getproperty(a.abm.properties, Symbol(obs))
end

function AlgebraicAgents.gettimeobservable(a::ABMAgent, t::Float64, obs)
    df = a.df_model
    @assert ("step" ∈ names(df)) && (string(obs) ∈ names(df))
    
    # query dataframe
    df[df.step .== Int(t), obs] |> first
end

function AlgebraicAgents._reinit!(a::ABMAgent)
    a.t = a.t0; a.abm = a.deepcopy(a.abm0)
    empty!(a.df_agents); empty!(a.df_model)

    a
end

# algebraic wrappers for AbstractAgent type
@oagent AAgent begin end

@doc "Algebraic wrap for `AbstractAgent` type." AAgent

# reference `Agents.AbstractAgent` via parent's ABM
Base.propertynames(::AAgent) = fieldname(AAgent) ∪ [:agent]

function Base.getproperty(a::AAgent, prop::Symbol)
    if prop == :agent
        getparent(a).abm.agents[parse(Int, getname(a))]
    else getfield(a, prop) end
end

## implement common interface
AlgebraicAgents._step!(::AAgent, ::Float64) = nothing
AlgebraicAgents._projected_to(::AAgent) = nothing

function AlgebraicAgents.getobservable(a::AAgent, obs)
    getproperty(a.agent, Symbol(obs))
end

function AlgebraicAgents.gettimeobservable(a::AAgent, t::Float64, obs)
    df = getparent(a).df_agents
    @assert ("step" ∈ names(df)) && (string(obs) ∈ names(df))
    
    # query df
    df[(df.step .== Int(t)) .& (df.id .== a.agent.id), obs] |> first
end

function AlgebraicAgents.print_custom(io::IO, mime::MIME"text/plain", a::ABMAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent+3), "custom properties:\n")
    print(io, " "^(indent+3), AlgebraicAgents.crayon"italics", "abm", ": ", AlgebraicAgents.crayon"reset", "\n")
    show(IOContext(io, :indent=>get(io, :indent, 0)+4), mime, a.abm)

    print(io, "\n" * " "^(indent+3), AlgebraicAgents.crayon"italics", "df_agents", ": ", AlgebraicAgents.crayon"reset", "\n")
    show(IOContext(io, :indent=>get(io, :indent, 0)+4), mime, a.df_model)

    print(io, "\n" * " "^(indent+3), AlgebraicAgents.crayon"italics", "df_model", ": ", AlgebraicAgents.crayon"reset", "\n")
    show(IOContext(io, :indent=>get(io, :indent, 0)+4), mime, a.df_agents)
end

function AlgebraicAgents.print_custom(io::IO, mime::MIME"text/plain", a::AAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent+3), "custom properties:\n")
    print(io, " "^(indent+3), AlgebraicAgents.crayon"italics", "agent", ": ", AlgebraicAgents.crayon"reset", "\n")
    show(IOContext(io, :indent=>get(io, :indent, 0)+4), mime, a.agent)
end

# macros to retrieve algebraic model's, agent's wrappers
"""
    @get_oagent model agent 
Retrieve agent's algebraic wrap from ABM's algebraic wrap.

# Examples
```julia
algebraic_agent = @get_oagent abm_model abm_agent
```
"""
macro get_oagent(model, agent)
    :($(esc(model)).properties[:__oagent__].inners[string($(esc(agent)).id)])
end

"""
    @get_omodel model
Retrieve model's algebraic wrap.

# Examples
```julia
algebraic_model = @get_omodel abm_model
```
"""
macro get_omodel(model)
    :($(esc(model)).properties[:__oagent__])
end

# macros to add, kill agents
function get_model(args...; kwargs...)
    vals = collect(args)
    ix = findfirst(i -> vals[i] isa Agents.AgentBasedModel, eachindex(vals))
    @assert !isnothing(ix)

    vals[ix]
end

"""
    @o operation
Algebraic extension of `add_agent!`, `kill_agent!`.

# Examples
```julia
@o add_agent!(model, 0.5)
@o disentangle!(agent, model)
```
"""
macro o(call)
    @assert Meta.isexpr(call, :call) && (call.args[1] ∈ [:kill_agent!, :add_agent!])
    model_call = deepcopy(call); model_call.args[1] = :(AgentsIntegration.get_model)
    
    if call.args[1] == :add_agent!
        quote
            model = $(esc(model_call))
            omodel = model isa AgentsIntegration.ABMAgent ? model : model.properties[:__oagent__]
            agent = $(esc(call))
            
            AlgebraicAgents.entangle!(omodel, AgentsIntegration.ABAModel(string(agent.id), a)) 
        end
    else
        agent = model_call.args[2]
        quote
            model = $(esc(model_call))
            omodel = model isa AgentsIntegration.ABMAgent ? model : model.properties[:__oagent__]
            
            agent = $(esc(agent))
            agent = agent isa Number ? string(agent) : string(agent.id)
            AlgebraicAgents.disentangle!(omodel.inners[agent])    

            $(esc(call))
        end
    end
end

# plot reduction
function AlgebraicAgents._draw(a::ABMAgent, args...; df_only=true, kwargs...)
    if df_only
        plot_model = isempty(a.df_model) ? nothing : AlgebraicAgents.@plot_df a.df_model
        plot_agents = isempty(a.df_agents) ? nothing : AlgebraicAgents.@plot_df a.df_agents
        isnothing(plot_model) ? plot_agents : 
            isnothing(plot_agents) ? plot_model : plot([plot_agents, plot_model])
    else InteractiveDynamics.abmplot(a.abm, args...; kwargs...) end
end


end