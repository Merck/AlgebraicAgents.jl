# AlgebraicDynamics.jl Integration

## System Wrap Types

```@docs
GraphicalAgent
GraphicalAgent(::AbstractString, ::AlgebraicAgents.GraphicalModelType)
```

## Conversion to a SciML Problem

```@docs
DiffEqAgent(::GraphicalAgent, args...)
```

## Sums

```@docs
⊕(::GraphicalAgent)
```