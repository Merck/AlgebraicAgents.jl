# Agents.jl Integration in AlgebraicAgents.jl

The integration can be loaded as:

```julia
using AlgebraicAgents
add_integration(:AgentsIntegration); using AgentsIntegration
```
```@meta
CurrentModule = AgentsIntegration
```
## Algebraic Wrap Types

```@docs
ABMAgent
AAgent
```

## Algebraic Bindings

```@docs
AgentsIntegration.@get_oagent
@o
```
