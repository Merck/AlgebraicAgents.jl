module AlgebraicAgentsAgentsExt

using AlgebraicAgents
using AlgebraicAgents: AbstractAlgebraicAgent, entangle!, projected_to,
    inners, getparent, getname
using Crayons

import Agents
import Agents.DataFrames

# implement constructor
function AlgebraicAgents.ABMAgent(
        name::AbstractString, abm::Agents.AgentBasedModel;
        when = true, when_model = when, step_size = 1.0,
        tspan::NTuple{2, Float64} = (0.0, Inf), kwargs...
    )

    i = AlgebraicAgents.ABMAgent(name)

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
        entangle!(i, AlgebraicAgents.AAgent(string(id)))
    end

    return i
end

function AlgebraicAgents.wrap_system(
        name::AbstractString, abm::Agents.AgentBasedModel, args...;
        kwargs...
    )
    return AlgebraicAgents.ABMAgent(name, abm, args...; kwargs...)
end

## implement common interface
function AlgebraicAgents._step!(a::AlgebraicAgents.ABMAgent)
    t = projected_to(a)
    step_size = a.step_size isa Number ? a.step_size : a.step_size(a.abm, t)
    collect_agents = a.when isa AbstractVector ? (t ∈ a.when) :
        a.when isa Bool ? a.when : a.when(a.abm, t)
    collect_model = a.when_model isa AbstractVector ? (t ∈ a.when_model) :
        a.when isa Bool ? a.when : a.when_model(a.abm, t)

    df_agents, df_model = Agents.run!(a.abm, 1.0; a.kwargs...)

    # append collected data
    ## df_agents
    if collect_agents && ("time" ∈ DataFrames.names(df_agents))
        if a.t == a.tspan[1]
            append!(a.df_agents, df_agents)
        else
            push!(a.df_agents, df_agents[end, :])
        end
    end
    ## df_model
    if collect_model && ("time" ∈ DataFrames.names(df_model))
        if a.t == a.tspan[1]
            append!(a.df_model, df_model)
        else
            push!(a.df_model, df_model[end, :])
        end
    end

    return a.t += step_size
end

# if step is a float, need to retype the dataframe
function fix_float!(df, val)
    return if eltype(df[!, :time]) <: Int && !isa(val, Int)
        df[!, :time] = convert.(Float64, df[!, :time])
    end
end

AlgebraicAgents._projected_to(a::AlgebraicAgents.ABMAgent) =
    a.tspan[2] <= a.t ? true : a.t

function AlgebraicAgents.getobservable(a::AlgebraicAgents.ABMAgent, obs)
    return getproperty(Agents.abmproperties(a.abm), Symbol(obs))
end

function AlgebraicAgents.gettimeobservable(a::AlgebraicAgents.ABMAgent, t::Float64, obs)
    df = a.df_model
    @assert ("time" ∈ DataFrames.names(df)) && (string(obs) ∈ DataFrames.names(df))

    # query dataframe
    return df[df.time .== Int(t), obs] |> first
end

function AlgebraicAgents._reinit!(a::AlgebraicAgents.ABMAgent)
    a.t = a.t0
    a.abm = deepcopy(a.abm0)
    empty!(a.df_agents)
    empty!(a.df_model)

    return a
end

# reference `Agents.AbstractAgent` via parent's ABM
Base.propertynames(::AlgebraicAgents.AAgent) =
    fieldnames(AlgebraicAgents.AAgent) ∪ [:agent]

function Base.getproperty(a::AlgebraicAgents.AAgent, prop::Symbol)
    return if prop == :agent
        (getparent(a).abm)[parse(Int, getname(a))]
    else
        getfield(a, prop)
    end
end

## implement common interface
AlgebraicAgents._step!(::AlgebraicAgents.AAgent) = nothing
AlgebraicAgents._projected_to(::AlgebraicAgents.AAgent) = nothing

function AlgebraicAgents.getobservable(a::AlgebraicAgents.AAgent, obs)
    return getproperty(a.agent, Symbol(obs))
end

function AlgebraicAgents.gettimeobservable(a::AlgebraicAgents.AAgent, t::Float64, obs)
    df = getparent(a).df_agents
    @assert ("time" ∈ DataFrames.names(df)) && (string(obs) ∈ DataFrames.names(df))

    # query df
    return df[(df.time .== Int(t)) .& (df.id .== a.agent.id), obs] |> first
end

function AlgebraicAgents.print_custom(
        io::IO, mime::MIME"text/plain", a::AlgebraicAgents.ABMAgent
    )
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "abm", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.abm)

    print(
        io, "\n" * " "^(indent + 3), crayon"italics", "df_agents", ": ", crayon"reset",
        "\n"
    )
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.df_model)

    print(
        io, "\n" * " "^(indent + 3), crayon"italics", "df_model", ": ", crayon"reset",
        "\n"
    )
    return show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.df_agents)
end

function AlgebraicAgents.print_custom(
        io::IO, mime::MIME"text/plain", a::AlgebraicAgents.AAgent
    )
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "agent", ": ", crayon"reset", "\n")
    return show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.agent)
end

# retrieve algebraic agent as a property of the core dynamical system
function AlgebraicAgents.extract_agent(model::Agents.ABM, agent::Agents.AbstractAgent)
    return Agents.abmproperties(model)[:__aagent__].inners[string(agent.id)]
end

# helper used by the `@a` macro
function AlgebraicAgents.get_model(args...; kwargs...)
    vals = collect(args)
    ix = findfirst(i -> vals[i] isa Agents.AgentBasedModel, eachindex(vals))
    @assert !isnothing(ix)

    return vals[ix]
end

end # module
