module AlgebraicAgentsAlgebraicDynamicsExt

using AlgebraicAgents
using AlgebraicAgents: AbstractAlgebraicAgent, entangle!, observables
using Crayons

import AlgebraicDynamics
using AlgebraicDynamics.DWDDynam: oapply
using AlgebraicDynamics.UWDDynam: oapply

const AbstractResourceSharer = AlgebraicDynamics.UWDDynam.AbstractResourceSharer
const AbstractMachine = AlgebraicDynamics.DWDDynam.AbstractMachine
const GraphicalModelType = Union{AbstractResourceSharer, AbstractMachine}

# `GraphicalAgent` itself is constructed via the macro-generated default
# constructor `GraphicalAgent(name, system)`; no SciML problem-shaped
# specialization is needed here.

function AlgebraicAgents.wrap_system(
        name::AbstractString, sharer::GraphicalModelType, args...;
        kwargs...
    )
    return AlgebraicAgents.GraphicalAgent(name, sharer, args...; kwargs...)
end

# implement common interface
AlgebraicAgents._step!(::AlgebraicAgents.GraphicalAgent) = nothing
AlgebraicAgents._projected_to(::AlgebraicAgents.GraphicalAgent) = nothing

function AlgebraicAgents.observables(a::AlgebraicAgents.GraphicalAgent)
    return if a.system isa AbstractMachine
        string.(a.system.interface.output_ports)
    else
        string.(a.system.interface.ports)
    end
end

# custom pretty-printing
function AlgebraicAgents.print_custom(
        io::IO, mime::MIME"text/plain", a::AlgebraicAgents.GraphicalAgent
    )
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "model", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.system)
    return print(io, " "^(indent + 3), crayon"italics", "ports: $(observables(a))")
end

# reduce sum `⊕` operation to `oapply`
function AlgebraicAgents.:⊕(
        x::Vector{M}; diagram, pushout = nothing,
        name = "diagram"
    ) where {M <: AlgebraicAgents.GraphicalAgent}
    x_ = map(x -> x.system, x)
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = AlgebraicAgents.GraphicalAgent(name, m)
    for x in x
        entangle!(m, x)
    end

    return m
end

function AlgebraicAgents.:⊕(
        x::Vararg{M}; diagram, pushout = nothing,
        name = "diagram"
    ) where {M <: AlgebraicAgents.GraphicalAgent}
    x_ = map(x -> x.system, collect(x))
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = AlgebraicAgents.GraphicalAgent(name, m)
    for x in x
        entangle!(m, x)
    end

    return m
end

function AlgebraicAgents.:⊕(
        x::AlgebraicAgents.GraphicalAgent;
        diagram, pushout = nothing, name = "diagram"
    )
    x_ = x.system
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = AlgebraicAgents.GraphicalAgent(name, m)
    entangle!(m, x)

    return m
end

function AlgebraicAgents.:⊕(
        x::AbstractDict{S, M}; diagram, pushout = nothing,
        name = "diagram"
    ) where {S, M <: AlgebraicAgents.GraphicalAgent}
    x_ = Dict(x -> x[1] => x[2].system, x)
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = AlgebraicAgents.GraphicalAgent(name, m)
    for x in values(x)
        entangle!(m, x)
    end

    return m
end

end # module
