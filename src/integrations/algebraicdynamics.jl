# `AbstractResourceSharer` / `AbstractMachine` algebraic wrap
"""
    GraphicalAgent(name, model)
Initialize algebraic wrap of either an `AbstractResourceSharer` or a `AbstractMachine`.

The wrapped `AbstractResourceSharer` or `AbstractMachine` is stored as the property `system`.

The constructor that accepts an `AlgebraicDynamics` model and the associated
`oapply`-based composition operators are provided by the
`AlgebraicAgentsAlgebraicDynamicsExt` package extension, which is loaded
automatically once `AlgebraicDynamics.jl` is available in the current
environment.

# Examples
```julia
GraphicalAgent("rabbit", ContinuousMachine{Float64}(1,1,1, dotr, (u, p, t) -> u))
```
"""
@aagent struct GraphicalAgent
    system::Any
end
