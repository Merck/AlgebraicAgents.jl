"""
    DiffEqAgent(name, problem[, alg]; observables=nothing, kwargs...)
Initialize DE problem algebraic wrap.

# Keywords
- `observables`: either `nothing` or a dictionary which maps keys to observable's positional index in `u`,
- other kwargs will be passed to the integrator during initialization step.

The fully-typed constructor is provided by the `AlgebraicAgentsSciMLExt`
package extension, which is loaded automatically once
`DifferentialEquations.jl` is available in the current environment.
"""
mutable struct DiffEqAgent <: AbstractAlgebraicAgent
    uuid::UUID
    name::AbstractString

    parent::Union{AbstractAlgebraicAgent, Nothing}
    inners::Dict{String, AbstractAlgebraicAgent}

    relpathrefs::Dict{AbstractString, UUID}
    opera::Opera

    # populated by the SciML extension
    integrator::Any

    observables::Dict{Any, Int}

    function DiffEqAgent(name::AbstractString)
        i = new()
        setup_agent!(i, name)
        i.observables = Dict{Any, Int}()
        return i
    end
end

# Inform users when methods are unreachable because the SciML extension is not loaded.
function DiffEqAgent(::AbstractString, ::Any, args...; kwargs...)
    return error(
        "`DiffEqAgent` requires the `AlgebraicAgentsSciMLExt` extension. " *
            "Load `DifferentialEquations` (e.g. `using DifferentialEquations`) before constructing `DiffEqAgent`."
    )
end

# `extract_agent` for SciML `Params` is provided by the extension.
