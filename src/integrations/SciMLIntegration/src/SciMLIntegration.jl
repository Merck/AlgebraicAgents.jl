module SciMLIntegration

using AlgebraicAgents
import SciMLBase, DiffEqBase, DifferentialEquations
import Plots

# wrap problem, integrator, solution type; DiffEq agents supertype 
export DiffEqAgent
# observables interface
export push_in_observables!, push_out_observables!
export @get_oagent

# define DE algebraic wrap
@oagent DiffEqAgent begin
    integrator::DiffEqBase.DEIntegrator

    out_observables::Union{Dict{Any, Int}, Nothing}
    in_observables::Union{Vector, Nothing}

    oref
end

@doc "Algebraic wrap of a SciML DE problem." DiffEqAgent

# implement agent constructor
"""
    DiffEqAgent(getname, problem[, alg]; out_observables=nothing, in_observables=nothing, oref=:__oagent__, kwargs...)
Initialize DE problem algebraic wrap. 

# Keywords
- `out_observables`: either `nothing` or a dictionary which maps keys to observable's positional index in `u`,
- `in_observables`: either `nothing` or a vector of (subjective) observables,
- `oref`: set key of algebraic wrap in problem's parameter space. By default `:__oagent__`;
set `nothing` to omit algebraic reference,
- other kwargs will be propagated to the integrator at initialization step.
"""
function DiffEqAgent(getname, problem::DiffEqBase.DEProblem, alg=DifferentialEquations.default_algorithm(problem)[1], args...;
        out_observables=nothing, in_observables=nothing, oref=:__oagent__, kwargs...
    )

    problem = if isnothing(oref) problem
    else
        p = (problem.p isa SciMLBase.NullParameters) ? Dict() : problem.p
        push!(p, oref => Val(DummyType))
        
        DifferentialEquations.remake(problem; p)
    end

    # initialize wrap
    i = DiffEqAgent(getname)

    i.integrator = DiffEqBase.init(problem, alg, args...; kwargs...)
    i.out_observables = out_observables; i.in_observables = in_observables
    i.oref = oref

    !isnothing(oref) && push!(i.integrator.p, oref => i)

    i
end

# implement common interface
function get_observable_index(a::DiffEqAgent, obs)
    isnothing(out_observables(a)) ? obs : get(out_observables(a), obs, obs)
end

function AlgebraicAgents.getobservable(a::DiffEqAgent, obs)
    a.integrator.u[get_observable_index(a, obs)]
end

function AlgebraicAgents.gettimeobservable(a::DiffEqAgent, t::Float64, obs)
    a.integrator(t)[get_observable_index(a, obs)]
end

"""
    @get_oagent p=:p key=:__oagent__
Retrieve algebraic wrap, which is stored under `key` in parameter space `p`.

# Examples
```julia
wrap = @get_oagent # assumes parameter space `p`, integrator's wrap ref `:__oagent__`
wrap = @get_oagent params
wrap = @get_oagent params :agent
```
"""
macro get_oagent(p=:p, key=:__oagent__)
    :($(esc(p))[$(QuoteNode(key))])
end

"""
    push_out_observables!(a::DiffEqAgent, pairs...)
Register explicit out-ports of an algebraic DiffEq model. 
Enables aliasing of variable's positional index. That is,
provide `key => ix` pair to alias `ix`th model's variable as `key`.

# Examples
```julia
push_out_observables!(deagent, key => ix1, ix2)
```
"""
function push_out_observables!(a::DiffEqAgent, pairs...)
    if isdefined(a, :out_observables) || isnothing(a.out_observables)
        (a.out_observables = Dict{Any, Int}())
    end
    for id in pairs
        push!(a.out_observables, id isa Pair ? id : (id => id))
    end

    a
end

"""
    push_in_observables!(a::DiffEqAgent, pairs...)
Register explicit in-ports of an algebraic DiffEq model.
Provide pairs `path => observable`, where `observable` may
optionally be an iterable collection of observables' names.

# Examples
```julia
push_out_observables!(deagent, path => observable, path => [observables...])
```
"""
function push_in_observables!(a::DiffEqAgent, pairs...)
    isdefined(a, :out_observables) || (a.out_observables = [])
    for id in pairs
        if id[2] isa Union{AbstractVec, Tuple}
            for o in id[2] push!(a.out_observables, id[1] => o) end
        else push!(a.out_observables, id) end
    end

    a
end

# implement internal step function
function AlgebraicAgents._step!(a::DiffEqAgent, t)
    if AlgebraicAgents.projected_to(a) === t
        ret = DiffEqBase.step!(a.integrator)
        ret == true && return true
    end

    a.integrator.t
end

function AlgebraicAgents._getparameters(a::DiffEqAgent)
    if a.integrator.p isa SciMLBase.NullParameters
        nothing
    elseif !isnothing(a.oref)
        dict = copy(a.integrator.p)
        pop!(dict, a.oref); dict
    else a.integrator.p end
end

function AlgebraicAgents._set_parameters!(a::DiffEqAgent, getparameters)
    params = a.integrator.p
    if params isa Dict
        merge!(params, getparameters)
    elseif params isa AbstractArray
        params .= getparameters
    end
end

AlgebraicAgents._projected_to(a::DiffEqAgent) = a.integrator.sol.prob.tspan[2] <= a.integrator.t ? true : a.integrator.t

AlgebraicAgents._reinit!(a::DiffEqAgent) = SciMLBase.reinit!(a.integrator)

function AlgebraicAgents.in_observables(a::DiffEqAgent)
    isdefined(a, :in_observables) ? a.in_observables : nothing
end

function AlgebraicAgents.out_observables(a::DiffEqAgent)
    isdefined(a, :out_observables) && !isnothing(a.out_observables) ? a.out_observables : nothing
end

# hacks integrator step
abstract type DummyType <: AbstractAlgebraicAgent end

AlgebraicAgents.getagent(::Val{DummyType}, args...) = Val(DummyType)
AlgebraicAgents.getobservable(::Val{DummyType}, args...) = 0
AlgebraicAgents.gettimeobservable(::Val{DummyType}, args...) = 0
AlgebraicAgents.getopera(::Val{DummyType}) = Val(DummyType)
AlgebraicAgents.AgentCall(::Val{DummyType}, args...) = Val(DummyType)
AlgebraicAgents.opera_enqueue!(::Val{DummyType}, args...) = nothing

# custom pretty-printing
function AlgebraicAgents.print_custom(io::IO, mime::MIME"text/plain", a::DiffEqAgent)
    indent = get(io, :indent, 0)
    print(io, "\n", " "^(indent+3), "custom properties:\n")
    print(io, " "^(indent+3), AlgebraicAgents.crayon"italics", "integrator", ": ", AlgebraicAgents.crayon"reset", "\n")
    show(IOContext(io, :indent=>get(io, :indent, 0)+4), mime, a.integrator)
    print_observables(IOContext(io, :indent=>get(io, :indent, 0)+3), mime, a)
end

"Print in/out observables of a DiffEq algebraic agent."
function print_observables(io::IO, ::MIME"text/plain", a::DiffEqAgent)
    indent = get(io, :indent, 0)
    if !isnothing(in_observables(a))
        print(io, "\n", " "^indent, AlgebraicAgents.crayon"italics", "ports in: ", AlgebraicAgents.crayon"reset")
        print(io, join(in_observables(a), ", "))
    end

    if !isnothing(out_observables(a))
        print(io, "\n", " "^indent, AlgebraicAgents.crayon"italics", "ports out: ", AlgebraicAgents.crayon"reset")
        print(io, join(keys(out_observables(a)), ", "))
    end
end

# plot reduction
function AlgebraicAgents._draw(a::DiffEqAgent, args...; kwargs...)
    Plots.plot(a.integrator.sol, args...; kwargs...)
end

end