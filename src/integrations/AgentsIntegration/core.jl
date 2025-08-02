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
    - any kwarg accepted by `Agents.run!`, incl. `adata`, `mdata`
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
            when = true, when_model = when, step_size = 1.0,
            tspan::NTuple{2, Float64} = (0.0, Inf), kwargs...)

        # initialize wrap
        i = new()
        setup_agent!(i, name)

        i.abm = abm
        i.kwargs = kwargs
        i.when = when
        i.when_model = when_model
        i.step_size = step_size
        i.tspan = tspan
        i.t = tspan[1]

        i.df_agents = DataFrames.DataFrame()
        i.df_model = DataFrames.DataFrame()

        Agents.abmproperties(i.abm)[:__aagent__] = i
        i.abm0 = deepcopy(i.abm)
        i.t0 = i.t

        # initialize contained agents
        for id in Agents.allids(abm)
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

    df_agents, df_model = Agents.run!(a.abm, 1.0; a.kwargs...)

    # append collected data
    ## df_agents
    if collect_agents && ("time" ∈ names(df_agents))
        if a.t == a.tspan[1]
            append!(a.df_agents, df_agents)
        else
            push!(a.df_agents, df_agents[end, :])
        end
    end
    ## df_model
    if collect_model && ("time" ∈ names(df_model))
        if a.t == a.tspan[1]
            append!(a.df_model, df_model)
        else
            push!(a.df_model, df_model[end, :])
        end
    end

    a.t += step_size
end

# if step is a float, need to retype the dataframe
function fix_float!(df, val)
    if eltype(df[!, :time]) <: Int && !isa(val, Int)
        df[!, :time] = convert.(Float64, df[!, :time])
    end
end

_projected_to(a::ABMAgent) = a.tspan[2] <= a.t ? true : a.t

function getobservable(a::ABMAgent, obs)
    getproperty(abmproperties(a.abm), Symbol(obs))
end

function gettimeobservable(a::ABMAgent, t::Float64, obs)
    df = a.df_model
    @assert ("time" ∈ names(df)) && (string(obs) ∈ names(df))

    # query dataframe
    df[df.time .== Int(t), obs] |> first
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
        (getparent(a).abm)[parse(Int, getname(a))]
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
    @assert ("time" ∈ names(df)) && (string(obs) ∈ names(df))

    # query df
    df[(df.time .== Int(t)) .& (df.id .== a.agent.id), obs] |> first
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
    abmproperties(model)[:__aagent__].inners[string(agent.id)]
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
    :(abmproperties($(esc(model)))[:__aagent__])
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
            omodel = model isa ABMAgent ? model : abmproperties(model)[:__aagent__]
            agent = $(esc(call))

            entangle!(omodel, ABAModel(string(agent.id), a))
        end
    else
        agent = model_call.args[2]
        quote
            model = $(esc(model_call))
            omodel = model isa ABMAgent ? model : abmproperties(model)[:__aagent__]

            agent = $(esc(agent))
            agent = agent isa Number ? string(agent) : string(agent.id)
            disentangle!(omodel.inners[agent])

            $(esc(call))
        end
    end
end
