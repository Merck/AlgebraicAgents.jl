import .AlgebraicDynamics

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

function _construct_agent(name::AbstractString, sharer::GraphicalModelType, args...;
                          kwargs...)
    GraphicalAgent(name, sharer, args...; kwargs...)
end

# implement common interface
getobservable(::GraphicalAgent, _) = nothing
_step!(::GraphicalAgent) = nothing
_projected_to(::GraphicalAgent) = nothing

function exposed_ports(a::GraphicalAgent)
    if a.system <: AbstractMachine
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
end

"Print in/out observables of a DiffEq algebraic agent."
function print_observables(io::IO, ::MIME"text/plain", a::GraphicalAgent)
    indent = get(io, :indent, 0)

    if !isnothing(exposed_ports(a))
        print(io, "\n", " "^indent, crayon"italics", "ports out: ", crayon"reset")
        print(io, join(keys(exposed_ports(a)), ", "))
    end
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
    m = isnothing(pushout) ? AlgebraicDynamics.oapply(diagram, x_) :
        AlgebraicDynamics.oapply(diagram, x, pushout)
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
    m = isnothing(pushout) ? AlgebraicDynamics.oapply(diagram, x_) :
        AlgebraicDynamics.oapply(diagram, x, pushout)
    m = GraphicalAgent(name, m)
    for x in x
        entangle!(m, x)
    end

    m
end

@doc sum_algebraicdynamics_docstring
function ⊕(x::GraphicalAgent; diagram, pushout = nothing, name = "diagram")
    x_ = x.system
    m = isnothing(pushout) ? AlgebraicDynamics.oapply(diagram, x_) :
        AlgebraicDynamics.oapply(diagram, x, pushout)
    m = GraphicalAgent(name, m)
    entangle!(m, x)

    m
end

@doc sum_algebraicdynamics_docstring
function ⊕(x::AbstractDict{S, M}; diagram, pushout = nothing,
           name = "diagram") where {S, M <: GraphicalAgent}
    x_ = Dict(x -> x[1] => x[2].system, x)
    m = isnothing(pushout) ? AlgebraicDynamics.oapply(diagram, x_) :
        AlgebraicDynamics.oapply(diagram, x, pushout)
    m = GraphicalAgent(name, m)
    for x in value(x)
        entangle!(m, x)
    end

    m
end
