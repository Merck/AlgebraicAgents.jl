import .Agents
import .Agents.DataFrames

export ABMAgent, AAgent
export @get_model, @a

# algebraic wrap for AgentBasedModel type
## agent types
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
mutable struct ABMAgent <: AbstractAlgebraicAgent
    # common interface fields
    uuid::UUID
    name::AbstractString

    parent::Union{AbstractAlgebraicAgent, Nothing}
    inners::Dict{String, AbstractAlgebraicAgent}

    relpathrefs::Dict{AbstractString, UUID}
    opera::Opera

    abm::Agents.AgentBasedModel

    agent_step!::Any
    model_step!::Any # evolutionary functions
    kwargs::Any # kwargs propagated to `run!` (incl. `adata`, `mdata`)
    when::Any
    when_model::Any # when to collect agents data, model data
    # true by default, and performs data collection at every step
    # if an `AbstractVector`, checks if `t ∈ when`; otherwise a function (model, t) -> ::Bool
    step_size::Any # how far the step advances, either a float or a function (model, t) -> size::Float64

    tspan::NTuple{2, Float64} # solution horizon, defaults to `(0., Inf)`
    t::Float64

    abm0::Agents.AgentBasedModel
    t0::Float64

    df_agents::DataFrames.DataFrame
    df_model::DataFrames.DataFrame

    ## implement constructor
    function ABMAgent(name::AbstractString, abm::Agents.AgentBasedModel;
        agent_step! = Agents.dummystep, model_step! = Agents.dummystep,
        when = true, when_model = when, step_size = 1.0,
        tspan::NTuple{2, Float64} = (0.0, Inf), kwargs...)

        # initialize wrap
        i = new()
        setup_agent!(i, name)

        i.abm = abm
        i.agent_step! = agent_step!
        i.model_step! = model_step!
        i.kwargs = kwargs
        i.when = when
        i.when_model = when_model
        i.step_size = step_size
        i.tspan = tspan
        i.t = tspan[1]

        i.df_agents = DataFrames.DataFrame()
        i.df_model = DataFrames.DataFrame()

        i.abm.properties[:__aagent__] = i
        i.abm0 = deepcopy(i.abm)
        i.t0 = i.t

        # initialize contained agents
        for (id, _) in abm.agents
            entangle!(i, AAgent(string(id)))
        end

        i
    end
end

function wrap_system(name::AbstractString, abm::Agents.AgentBasedModel, args...;
    kwargs...)
    ABMAgent(name, abm, args...; kwargs...)
end

## implement common interface
function _step!(a::ABMAgent)
    t = projected_to(a)
    step_size = a.step_size isa Number ? a.step_size : a.step_size(a.abm, t)
    collect_agents = a.when isa AbstractVector ? (t ∈ a.when) :
                     a.when isa Bool ? a.when : a.when(a.abm, t)
    collect_model = a.when_model isa AbstractVector ? (t ∈ a.when_model) :
                    a.when isa Bool ? a.when : a.when_model(a.abm, t)

    df_agents, df_model = Agents.run!(a.abm, a.agent_step!, a.model_step!, 1;
        a.kwargs...)
    # append collected data
    ## df_agents
    if collect_agents && ("step" ∈ names(df_agents))
        if a.t == a.tspan[1]
            df_agents_0 = df_agents[df_agents.step .== 0.0, :]
            df_agents_0[!, :step] = convert.(Float64, df_agents_0[!, :step])
            df_agents_0[!, :step] .+= a.t
            append!(a.df_agents, df_agents_0)
        end
        df_agents = df_agents[df_agents.step .== 1.0, :]
        append!(a.df_agents, df_agents)
        a.df_agents[(end - DataFrames.nrow(df_agents) + 1):end, :step] .+= a.t +
                                                                           step_size - 1
    end
    ## df_model
    if collect_model && ("step" ∈ names(df_model))
        if a.t == a.tspan[1]
            df_model_0 = df_model[df_model.step .== 0.0, :]
            df_model_0[!, :step] = convert.(Float64, df_model_0[!, :step])
            df_model_0[!, :step] .+= a.t
            append!(a.df_model, df_model_0)
        end
        df_model = df_model[df_model.step .== 1.0, :]
        append!(a.df_model, df_model)
        a.df_model[(end - DataFrames.nrow(df_model) + 1):end, :step] .+= a.t +
                                                                         step_size - 1
    end

    a.t += step_size
end

# if step is a float, need to retype the dataframe
function fix_float!(df, val)
    if eltype(df[!, :step]) <: Int && !isa(val, Int)
        df[!, :step] = convert.(Float64, df[!, :step])
    end
end

_projected_to(a::ABMAgent) = a.tspan[2] <= a.t ? true : a.t

function getobservable(a::ABMAgent, obs)
    getproperty(a.abm.properties, Symbol(obs))
end

function gettimeobservable(a::ABMAgent, t::Float64, obs)
    df = a.df_model
    @assert ("step" ∈ names(df)) && (string(obs) ∈ names(df))

    # query dataframe
    df[df.step .== Int(t), obs] |> first
end

function _reinit!(a::ABMAgent)
    a.t = a.t0
    a.abm = a.deepcopy(a.abm0)
    empty!(a.df_agents)
    empty!(a.df_model)

    a
end

# algebraic wrappers for AbstractAgent type
"Algebraic wrap for `AbstractAgent` type."
@aagent struct AAgent end

# reference `Agents.AbstractAgent` via parent's ABM
Base.propertynames(::AAgent) = fieldnames(AAgent) ∪ [:agent]

function Base.getproperty(a::AAgent, prop::Symbol)
    if prop == :agent
        getparent(a).abm.agents[parse(Int, getname(a))]
    else
        getfield(a, prop)
    end
end

## implement common interface
_step!(::AAgent) = nothing
_projected_to(::AAgent) = nothing

function getobservable(a::AAgent, obs)
    getproperty(a.agent, Symbol(obs))
end

function gettimeobservable(a::AAgent, t::Float64, obs)
    df = getparent(a).df_agents
    @assert ("step" ∈ names(df)) && (string(obs) ∈ names(df))

    # query df
    df[(df.step .== Int(t)) .& (df.id .== a.agent.id), obs] |> first
end

function print_custom(io::IO, mime::MIME"text/plain", a::ABMAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "abm", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.abm)

    print(io, "\n" * " "^(indent + 3), crayon"italics", "df_agents", ": ", crayon"reset",
        "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.df_model)

    print(io, "\n" * " "^(indent + 3), crayon"italics", "df_model", ": ", crayon"reset",
        "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.df_agents)
end

function print_custom(io::IO, mime::MIME"text/plain", a::AAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "agent", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.agent)
end

# retrieve algebraic agent as a property of the core dynamical system
function extract_agent(model::Agents.ABM, agent::Agents.AbstractAgent)
    model.properties[:__aagent__].inners[string(agent.id)]
end

"""
    @get_model model
Retrieve model's algebraic wrap.

# Examples
```julia
algebraic_model = @get_model abm_model
```
"""
macro get_model(model)
    :($(esc(model)).properties[:__aagent__])
end

# macros to add, kill agents
function get_model(args...; kwargs...)
    vals = collect(args)
    ix = findfirst(i -> vals[i] isa Agents.AgentBasedModel, eachindex(vals))
    @assert !isnothing(ix)

    vals[ix]
end

"""
    @a operation
Algebraic extension of `add_agent!`, `kill_agent!`.

# Examples
```julia
@a add_agent!(model, 0.5)
@a disentangle!(agent, model)
```
"""
macro a(call)
    @assert Meta.isexpr(call, :call) && (call.args[1] ∈ [:kill_agent!, :add_agent!])
    model_call = deepcopy(call)
    model_call.args[1] = :(AlgebraicAgents.get_model)

    if call.args[1] == :add_agent!
        quote
            model = $(esc(model_call))
            omodel = model isa ABMAgent ? model : model.properties[:__aagent__]
            agent = $(esc(call))

            entangle!(omodel, ABAModel(string(agent.id), a))
        end
    else
        agent = model_call.args[2]
        quote
            model = $(esc(model_call))
            omodel = model isa ABMAgent ? model : model.properties[:__aagent__]

            agent = $(esc(agent))
            agent = agent isa Number ? string(agent) : string(agent.id)
            disentangle!(omodel.inners[agent])

            $(esc(call))
        end
    end
end

function _draw(a::ABMAgent, args...; kwargs...)
    @warn "`ABMAgent` requires package `Plots` to be loaded for plotting"
end
