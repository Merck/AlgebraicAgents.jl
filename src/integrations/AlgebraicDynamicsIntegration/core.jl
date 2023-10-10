import .AlgebraicDynamics

using .AlgebraicDynamics.DWDDynam: oapply
using .AlgebraicDynamics.UWDDynam: oapply

export GraphicalAgent

const AbstractResourceSharer = AlgebraicDynamics.UWDDynam.AbstractResourceSharer
const AbstractMachine = AlgebraicDynamics.DWDDynam.AbstractMachine
const GraphicalModelType = Union{AbstractResourceSharer, AbstractMachine}

# define wrap types
# `AbstractResourceSharer`, `AbstractMachine` wrap
"""
    GraphicalAgent(name, model)
Initialize algebraic wrap of either an `AbstractResourceSharer` or a `AbstractMachine`.

The wrapped `AbstractResourceSharer` or `AbstractMachine` is stored as the property `system`.

# Examples
```julia
GraphicalAgent("rabbit", ContinuousMachine{Float64}(1,1,1, dotr, (u, p, t) -> u))
```
"""
@aagent struct GraphicalAgent
    system::GraphicalModelType
end

function wrap_system(name::AbstractString, sharer::GraphicalModelType, args...;
    kwargs...)
    GraphicalAgent(name, sharer, args...; kwargs...)
end

# implement common interface
_step!(::GraphicalAgent) = nothing
_projected_to(::GraphicalAgent) = nothing

function observables(a::GraphicalAgent)
    if a.system isa AbstractMachine
        string.(a.system.interface.output_ports)
    else
        string.(a.system.interface.ports)
    end
end

# custom pretty-printing
function print_custom(io::IO, mime::MIME"text/plain", a::GraphicalAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "model", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.system)
    print(io, " "^(indent + 3), crayon"italics", "ports: $(observables(a))")
end

# reduce sum `⊕` operation to `oapply`
const sum_algebraicdynamics_docstring = """
    ⊕(system1, system2; diagram=pattern, name)
    ⊕([system1, system2]; diagram=pattern, name)
    ⊕(Dict(:system1 => system1, :system2 => system2); diagram=pattern, name)
Apply `oapply(diagram, systems...)` and wrap the result as a `GraphicalAgent`.
"""

@doc sum_algebraicdynamics_docstring
function ⊕(x::Vector{M}; diagram, pushout = nothing,
    name = "diagram") where {M <: GraphicalAgent}
    x_ = map(x -> x.system, x)
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = GraphicalAgent(name, m)
    for x in x
        entangle!(m, x)
    end

    m
end

@doc sum_algebraicdynamics_docstring
function ⊕(x::Vararg{M}; diagram, pushout = nothing,
    name = "diagram") where {M <: GraphicalAgent}
    x_ = map(x -> x.system, collect(x))
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = GraphicalAgent(name, m)
    for x in x
        entangle!(m, x)
    end

    m
end

@doc sum_algebraicdynamics_docstring
function ⊕(x::GraphicalAgent; diagram, pushout = nothing, name = "diagram")
    x_ = x.system
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = GraphicalAgent(name, m)
    entangle!(m, x)

    m
end

@doc sum_algebraicdynamics_docstring
function ⊕(x::AbstractDict{S, M}; diagram, pushout = nothing,
    name = "diagram") where {S, M <: GraphicalAgent}
    x_ = Dict(x -> x[1] => x[2].system, x)
    m = isnothing(pushout) ? oapply(diagram, x_) :
        oapply(diagram, x, pushout)
    m = GraphicalAgent(name, m)
    for x in value(x)
        entangle!(m, x)
    end

    m
end
