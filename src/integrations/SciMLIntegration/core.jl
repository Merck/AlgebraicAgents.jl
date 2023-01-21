import .DifferentialEquations
import .DifferentialEquations: DiffEqBase, SciMLBase, OrdinaryDiffEq

# wrap problem, integrator, solution type; DiffEq agents supertype 
export DiffEqAgent
# observables interface
export push_ports_in!, push_exposed_ports!

# define DE algebraic wrap
"""
    DiffEqAgent(name, problem[, alg]; exposed_ports=nothing, ports_in=nothing, kwargs...)
Initialize DE problem algebraic wrap. 

# Keywords
- `exposed_ports`: either `nothing` or a dictionary which maps keys to observable's positional index in `u`,
- `ports_in`: either `nothing` or a vector of (subjective) observables,
- other kwargs will be propagated to the integrator at initialization step.
"""
mutable struct DiffEqAgent <: AbstractAlgebraicAgent
    uuid::UUID
    name::AbstractString

    parent::Union{AbstractAlgebraicAgent, Nothing}
    inners::Dict{String, AbstractAlgebraicAgent}

    relpathrefs::Dict{AbstractString, UUID}
    opera::Opera

    integrator::DiffEqBase.DEIntegrator

    exposed_ports::Union{Dict{Any, Int}, Nothing}
    ports_in::Union{Vector, Nothing}

    function DiffEqAgent(name, problem::DiffEqBase.DEProblem,
                         alg = DifferentialEquations.default_algorithm(problem)[1], args...;
                         exposed_ports = nothing, ports_in = nothing, kwargs...)
        problem = DifferentialEquations.remake(problem;
                                               p = Params(Val(DummyType), problem.p))

        # initialize wrap
        i = new()
        setup_agent!(i, name)

        i.integrator = DiffEqBase.init(problem, alg, args...; kwargs...)
        i.exposed_ports = exposed_ports
        i.ports_in = ports_in

        i.integrator.p.agent = i

        i
    end
end

## params wrap
mutable struct Params
    agent::Any
    params::Any
end

# property indexing
function Base.getproperty(p::Params, k::Symbol)
    k == :agent ? getfield(p, :agent) : getproperty(getfield(p, :params), k)
end

Base.propertynames(p::Params) = propertynames(getfield(p, :params))

# vector interface
Base.length(p::Params) = length(getfield(p, :params))
Base.getindex(p::Params, i::Int) = getfield(p, :params)[i]
function Base.getindex(::Params, ::Any)
    @error "please pass, and index, params as a vector, see https://github.com/SciML/SciMLBase.jl/pull/262"
end
Base.setindex!(p::Params, v, i::Int) = getfield(p, :params)[i] = v

function _construct_agent(name::AbstractString, problem::DiffEqBase.DEProblem, args...;
                          alg = DifferentialEquations.default_algorithm(problem)[1],
                          kwargs...)
    DiffEqAgent(name, problem, alg, args...; kwargs...)
end

# implement common interface
function getobservable_index(a::DiffEqAgent, obs)
    isnothing(exposed_ports(a)) ? obs : get(exposed_ports(a), obs, obs)
end

function getobservable(a::DiffEqAgent, obs)
    a.integrator.u[getobservable_index(a, obs)]
end

function gettimeobservable(a::DiffEqAgent, t::Float64, obs)
    a.integrator(t)[getobservable_index(a, obs)]
end

"""
    push_exposed_ports!(a::DiffEqAgent, pairs...)
Register explicit out-ports of an algebraic DiffEq model. 
Enables aliasing of variable's positional index. That is,
provide `key => ix` pair to alias `ix`th model's variable as `key`.

# Examples
```julia
push_exposed_ports!(deagent, key => ix1, ix2)
```
"""
function push_exposed_ports!(a::DiffEqAgent, pairs...)
    if isdefined(a, :exposed_ports) || isnothing(a.exposed_ports)
        (a.exposed_ports = Dict{Any, Int}())
    end
    for id in pairs
        push!(a.exposed_ports, id isa Pair ? id : (id => id))
    end

    a
end

"""
    push_ports_in!(a::DiffEqAgent, pairs...)
Register explicit in-ports of an algebraic DiffEq model.
Provide pairs `path => observable`, where `observable` may
optionally be an iterable collection of observables' names.

# Examples
```julia
push_ports_in!(deagent, path => observable, path => [observables...])
```
"""
function push_ports_in!(a::DiffEqAgent, pairs...)
    if isdefined(a, :ports_in) || isnothing(a.ports_in)
        a.ports_in = []
    end
    for id in pairs
        if id[2] isa Union{AbstractVector, Tuple}
            for o in id[2]
                push!(a.ports_in, id[1] => o)
            end
        else
            push!(a.ports_in, id)
        end
    end

    a
end

# implement internal step function
function _step!(a::DiffEqAgent, t)
    if projected_to(a) === t
        ret = DiffEqBase.step!(a.integrator)
        ret == true && return true
    end

    a.integrator.t
end

function _getparameters(a::DiffEqAgent)
    p = getfield(a.integrator.p, :params)

    p isa SciMLBase.NullParameters ? nothing : p
end

function _setparameters!(a::DiffEqAgent, getparameters)
    params = getfield(a.integrator.p, :params)
    if params isa Dict
        merge!(params, getparameters)
    elseif params isa AbstractArray
        params .= getparameters
    end
end

function _projected_to(a::DiffEqAgent)
    a.integrator.sol.prob.tspan[2] <= a.integrator.t ? true : a.integrator.t
end

_reinit!(a::DiffEqAgent) = SciMLBase.reinit!(a.integrator)

function ports_in(a::DiffEqAgent)
    isdefined(a, :ports_in) ? a.ports_in : nothing
end

function exposed_ports(a::DiffEqAgent)
    isdefined(a, :exposed_ports) && !isnothing(a.exposed_ports) ? a.exposed_ports : nothing
end

# hacks integrator step
abstract type DummyType <: AbstractAlgebraicAgent end

getagent(::Val{DummyType}, args...) = Val(DummyType)
getobservable(::Val{DummyType}, args...) = 0
gettimeobservable(::Val{DummyType}, args...) = 0
getopera(::Val{DummyType}) = Val(DummyType)
AgentCall(::Val{DummyType}, args...) = Val(DummyType)
opera_enqueue!(::Val{DummyType}, args...) = nothing

# custom pretty-printing
function print_custom(io::IO, mime::MIME"text/plain", a::DiffEqAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "integrator", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.integrator)
    print_observables(IOContext(io, :indent => get(io, :indent, 0) + 3), mime, a)
end

"Print in/out observables of a DiffEq algebraic agent."
function print_observables(io::IO, ::MIME"text/plain", a::DiffEqAgent)
    indent = get(io, :indent, 0)
    if !isnothing(ports_in(a))
        print(io, "\n", " "^indent, crayon"italics", "ports in: ", crayon"reset")
        print(io, join(ports_in(a), ", "))
    end

    if !isnothing(exposed_ports(a))
        print(io, "\n", " "^indent, crayon"italics", "ports out: ", crayon"reset")
        print(io, join(keys(exposed_ports(a)), ", "))
    end
end

function _draw(a::DiffEqAgent, args...; kwargs...)
    @warn "`DiffEqAgent` requires package `Plots` to be loaded for plotting"
end

_get_agent(p::Params) = p.agent
