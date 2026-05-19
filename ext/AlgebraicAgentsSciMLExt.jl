module AlgebraicAgentsSciMLExt

using AlgebraicAgents
using AlgebraicAgents: AbstractAlgebraicAgent, observables
using Crayons

import DifferentialEquations
import DifferentialEquations: SciMLBase

# constructor that accepts a `DifferentialEquations` problem

function AlgebraicAgents.DiffEqAgent(
        name::AbstractString,
        problem::SciMLBase.AbstractDEProblem,
        alg = DifferentialEquations.DefaultODEAlgorithm(autodiff = DifferentialEquations.ADTypes.AutoFiniteDiff()),
        args...;
        observables = Dict{Any, Int}(), kwargs...
    )
    problem = DifferentialEquations.remake(
        problem;
        p = Params(Val(DummyType), problem.p)
    )

    i = AlgebraicAgents.DiffEqAgent(name)
    i.integrator = SciMLBase.init(problem, alg, args...; kwargs...)
    i.observables = observables
    i.integrator.p.agent = i

    return i
end

## params wrap
mutable struct Params
    agent::Any
    params::Any
end

# property indexing
function Base.getproperty(p::Params, k::Symbol)
    return k == :agent ? getfield(p, :agent) : getproperty(getfield(p, :params), k)
end

Base.propertynames(p::Params) = propertynames(getfield(p, :params))

# vector interface
Base.length(p::Params) = length(getfield(p, :params))
Base.getindex(p::Params, i::Int) = getfield(p, :params)[i]
function Base.getindex(::Params, ::Any)
    return @error "please pass, and index, params as a vector, see https://github.com/SciML/SciMLBase.jl/pull/262"
end
Base.setindex!(p::Params, v, i::Int) = getfield(p, :params)[i] = v

function AlgebraicAgents.wrap_system(
        name::AbstractString, problem::SciMLBase.AbstractDEProblem, args...;
        alg = DifferentialEquations.DefaultODEAlgorithm(autodiff = DifferentialEquations.ADTypes.AutoFiniteDiff()),
        kwargs...
    )
    return AlgebraicAgents.DiffEqAgent(name, problem, alg, args...; kwargs...)
end

# implement common interface
getobservable_index(a::AlgebraicAgents.DiffEqAgent, obs) = get(observables(a), obs, obs)

function AlgebraicAgents.getobservable(a::AlgebraicAgents.DiffEqAgent, obs)
    return a.integrator.u[getobservable_index(a, obs)]
end

function AlgebraicAgents.gettimeobservable(
        a::AlgebraicAgents.DiffEqAgent, t::Float64, obs
    )
    return a.integrator(t)[getobservable_index(a, obs)]
end

# implement internal step function
function AlgebraicAgents._step!(a::AlgebraicAgents.DiffEqAgent)
    ret = SciMLBase.step!(a.integrator)
    return ret == true && return true
end

function AlgebraicAgents._getparameters(a::AlgebraicAgents.DiffEqAgent)
    p = getfield(a.integrator.p, :params)

    return p isa SciMLBase.NullParameters ? nothing : p
end

function AlgebraicAgents._setparameters!(a::AlgebraicAgents.DiffEqAgent, getparameters)
    params = getfield(a.integrator.p, :params)
    return if params isa Dict
        merge!(params, getparameters)
    elseif params isa AbstractArray
        params .= getparameters
    end
end

function AlgebraicAgents._projected_to(a::AlgebraicAgents.DiffEqAgent)
    return a.integrator.sol.prob.tspan[2] <= a.integrator.t ? true : a.integrator.t
end

AlgebraicAgents._reinit!(a::AlgebraicAgents.DiffEqAgent) = SciMLBase.reinit!(a.integrator)

AlgebraicAgents.observables(a::AlgebraicAgents.DiffEqAgent) = a.observables

# hacks integrator step
abstract type DummyType <: AbstractAlgebraicAgent end

AlgebraicAgents.getagent(::Val{DummyType}, args...) = Val(DummyType)
AlgebraicAgents.getobservable(::Val{DummyType}, args...) = 0
AlgebraicAgents.gettimeobservable(::Val{DummyType}, args...) = 0
AlgebraicAgents.getopera(::Val{DummyType}) = Val(DummyType)
AlgebraicAgents.add_instantious!(::Val{DummyType}, args...) = nothing
AlgebraicAgents.get_count(::Val{DummyType}, args...) = "nothing"
AlgebraicAgents.add_future!(::Val{DummyType}, args...) = "nothing"
AlgebraicAgents.add_control!(::Val{DummyType}, args...) = "nothing"

# custom pretty-printing
function AlgebraicAgents.print_custom(
        io::IO, mime::MIME"text/plain", a::AlgebraicAgents.DiffEqAgent
    )
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "integrator", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.integrator)
    return print_observables(IOContext(io, :indent => get(io, :indent, 0) + 3), mime, a)
end

"Print observables (positional indices and pretty names of \"exported variables\") of a `DiffEqAgent`."
function print_observables(io::IO, ::MIME"text/plain", a::AlgebraicAgents.DiffEqAgent)
    indent = get(io, :indent, 0)

    return if !isempty(observables(a))
        print(io, "\n", " "^indent, crayon"italics", "observables: ", crayon"reset")
        print(io, join(["$key (index: $val)" for (key, val) in observables(a)], ", "))
    end
end

# retrieve algebraic agent as a property of the core dynamical system
AlgebraicAgents.extract_agent(p::Params) = p.agent

end # module
