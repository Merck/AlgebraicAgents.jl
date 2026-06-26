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

The fully-typed constructor and stepping logic are provided by the
`AlgebraicAgentsAgentsExt` package extension, which is loaded automatically
once `Agents.jl` is available in the current environment.
"""
mutable struct ABMAgent <: AbstractAlgebraicAgent
    # common interface fields
    uuid::UUID
    name::AbstractString

    parent::Union{AbstractAlgebraicAgent, Nothing}
    inners::Dict{String, AbstractAlgebraicAgent}

    relpathrefs::Dict{AbstractString, UUID}
    opera::Opera

    abm::Any  # Agents.AgentBasedModel; populated by the Agents extension

    kwargs::Any # kwargs propagated to `run!` (incl. `adata`, `mdata`)
    when::Any
    when_model::Any # when to collect agents data, model data
    # true by default, and performs data collection at every step
    # if an `AbstractVector`, checks if `t ∈ when`; otherwise a function (model, t) -> ::Bool
    step_size::Any # how far the step advances, either a float or a function (model, t) -> size::Float64

    tspan::NTuple{2, Float64} # solution horizon, defaults to `(0., Inf)`
    t::Float64

    abm0::Any
    t0::Float64

    df_agents::Any  # DataFrames.DataFrame
    df_model::Any   # DataFrames.DataFrame

    function ABMAgent(name::AbstractString)
        i = new()
        setup_agent!(i, name)
        return i
    end
end

# Inform users when methods are unreachable because the Agents extension is not loaded.
function ABMAgent(::AbstractString, ::Any, args...; kwargs...)
    return error(
        "`ABMAgent` requires the `AlgebraicAgentsAgentsExt` extension. " *
            "Load `Agents` (e.g. `using Agents`) before constructing `ABMAgent`."
    )
end

# algebraic wrappers for AbstractAgent type
"Algebraic wrap for `Agents.AbstractAgent`."
@aagent struct AAgent end

"""
    @get_model model
Retrieve model's algebraic wrap.

Requires the `AlgebraicAgentsAgentsExt` extension (i.e. `Agents.jl` loaded).

# Examples
```julia
algebraic_model = @get_model abm_model
```
"""
macro get_model(model)
    # `AlgebraicAgents.get_abm_wrap` is specialized in the Agents extension; we
    # route through it instead of emitting a bare `Agents.abmproperties` call,
    # which would resolve `Agents` in this module (a weakdep with no binding here).
    return :(AlgebraicAgents.get_abm_wrap($(esc(model))))
end

"""
    @a operation
Algebraic extension of `add_agent!`, `kill_agent!`.

Requires the `AlgebraicAgentsAgentsExt` extension (i.e. `Agents.jl` loaded).

# Examples
```julia
@a add_agent!(model, 0.5)
@a remove_agent!(agent, model)
```
"""
macro a(call)
    @assert Meta.isexpr(call, :call) &&
        (call.args[1] ∈ [:kill_agent!, :remove_agent!, :add_agent!])
    model_call = deepcopy(call)
    model_call.args[1] = :(AlgebraicAgents.get_model)

    return if call.args[1] == :add_agent!
        quote
            model = $(esc(model_call))
            omodel = model isa ABMAgent ? model : AlgebraicAgents.get_abm_wrap(model)
            agent = $(esc(call))

            entangle!(omodel, AAgent(string(agent.id)))
            agent
        end
    else
        agent = model_call.args[2]
        quote
            model = $(esc(model_call))
            omodel = model isa ABMAgent ? model : AlgebraicAgents.get_abm_wrap(model)

            agent = $(esc(agent))
            agent = agent isa Number ? string(agent) : string(agent.id)
            disentangle!(omodel.inners[agent])

            $(esc(call))
        end
    end
end

# helper used by the `@a` macro; the extension specializes its dispatch.
function get_model end

# retrieves the algebraic wrap stored in an ABM's properties; specialized in the
# `AlgebraicAgentsAgentsExt` extension. Used by `@get_model` and `@a` so the macros
# need not reference the `Agents` weakdep directly.
function get_abm_wrap end
