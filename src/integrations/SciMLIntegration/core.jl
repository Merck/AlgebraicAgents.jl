import .DifferentialEquations
import .DifferentialEquations: DiffEqBase, SciMLBase, OrdinaryDiffEq

# wrap problem, integrator, solution type; DiffEq agents supertype 
export DiffEqAgent
# observables interface
export add_observables!

# define DE algebraic wrap
"""
    DiffEqAgent(name, problem[, alg]; observables=nothing, kwargs...)
Initialize DE problem algebraic wrap. 

# Keywords
- `observables`: either `nothing` or a dictionary which maps keys to observable's positional index in `u`,
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

    observables::Union{Dict{Any, Int}, Nothing}

    function DiffEqAgent(name, problem::DiffEqBase.DEProblem,
                         alg = DifferentialEquations.default_algorithm(problem)[1], args...;
                         observables = nothing, kwargs...)
        problem = DifferentialEquations.remake(problem;
                                               p = Params(Val(DummyType), problem.p))

        # initialize wrap
        i = new()
        setup_agent!(i, name)

        i.integrator = DiffEqBase.init(problem, alg, args...; kwargs...)
        i.observables = observables

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
    isnothing(observables(a)) ? obs : get(observables(a), obs, obs)
end

function getobservable(a::DiffEqAgent, obs)
    a.integrator.u[getobservable_index(a, obs)]
end

function gettimeobservable(a::DiffEqAgent, t::Float64, obs)
    a.integrator(t)[getobservable_index(a, obs)]
end

"""
    add_observables!(a::DiffEqAgent, pairs...)
Register observables of an algebraic DiffEq model. 
Enables aliasing of variable's positional index. That is,
provide `key => ix` pair to alias `ix`th model's variable as `key`.

# Examples
```julia
add_observables!(deagent, key => ix1, ix2)
```
"""
function add_observables!(a::DiffEqAgent, pairs...)
    if isdefined(a, :observables) || isnothing(a.observables)
        (a.observables = Dict{Any, Int}())
    end
    for id in pairs
        push!(a.observables, id isa Pair ? id : (id => id))
    end

    a
end

# implement internal step function
function _step!(a::DiffEqAgent)
    ret = DiffEqBase.step!(a.integrator)
    ret == true && return true
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

function observables(a::DiffEqAgent)
    isdefined(a, :observables) && !isnothing(a.observables) ? a.observables : nothing
end

# hacks integrator step
abstract type DummyType <: AbstractAlgebraicAgent end

getagent(::Val{DummyType}, args...) = Val(DummyType)
getobservable(::Val{DummyType}, args...) = 0
gettimeobservable(::Val{DummyType}, args...) = 0
getopera(::Val{DummyType}) = Val(DummyType)
AgentCall(::Val{DummyType}, args...) = Val(DummyType)
add_instantious!(::Val{DummyType}, args...) = nothing
get_count(::Val{DummyType}, args...) = "nothing"
add_future!(::Val{DummyType}, args...) = "nothing"
add_control!(::Val{DummyType}, args...) = "nothing"

# custom pretty-printing
function print_custom(io::IO, mime::MIME"text/plain", a::DiffEqAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent + 3), "custom properties:\n")
    print(io, " "^(indent + 3), crayon"italics", "integrator", ": ", crayon"reset", "\n")
    show(IOContext(io, :indent => get(io, :indent, 0) + 4), mime, a.integrator)
    print_observables(IOContext(io, :indent => get(io, :indent, 0) + 3), mime, a)
end

"Print in/out observables of a DiffEq nt."
function print_observables(io::IO, ::MIME"text/plain", a::DiffEqAgent)
    indent = get(io, :indent, 0)

    if !isnothing(observables(a))
        print(io, "\n", " "^indent, crayon"italics", "observables: ", crayon"reset")
        print(io, join(keys(observables(a)), ", "))
    end
end

function _draw(a::DiffEqAgent, args...; kwargs...)
    @warn "`DiffEqAgent` requires package `Plots` to be loaded for plotting"
end

_get_agent(p::Params) = p.agent
