import .DifferentialEquations
import .DifferentialEquations: OrdinaryDiffEq

function _get_problem_type(system::GraphicalModelType)
    if typeof(system) <: Union{AlgebraicDynamics.DWDDynam.ContinuousMachine,
             AlgebraicDynamics.UWDDynam.ContinuousResourceSharer}
        OrdinaryDiffEq.ODEProblem
    elseif typeof(system) <: Union{AlgebraicDynamics.DWDDynam.DiscreteMachine,
                 AlgebraicDynamics.UWDDynam.DiscreteResourceSharer}
        OrdinaryDiffEq.DiscreteProblem
    else
        OrdinaryDiffEq.DDEProblem
    end
end

# conversion to DiffEqAgent
"""
    DiffEqAgent(agent::GraphicalAgent, u0, tspan, p; alg, kwargs...)
Infer a problem type parametrized by `agent.system`, and create an appropriate `DEProblem`.
Moreover, wrap this problem as an instance of `DiffEqAgent`; this contains `agent`'s inner hierarchy.

# Examples
```julia
DiffEqAgent(system, u0, tspan, params)
DiffEqAgent(system, u0, tspan, params; alg=Tsit5())
```
"""
function DiffEqAgent(agent::GraphicalAgent, args...;
                     alg = nothing, kwargs...)
    # get DEProblem
    prob = _get_problem_type(agent.system)(agent.system, args...)
    # get alg
    alg = !isnothing(alg) ? alg : DifferentialEquations.default_algorithm(prob)[1]
    # wrap, entangle
    agent_ = DiffEqAgent(agent.name, prob; kwargs...)
    inner_agents = values(inners(agent))
    disentangle!(agent)
    @info "disentangling root `GraphicalAgent`"
    foreach(a -> entangle!(agent_, a), inner_agents)

    agent_
end
