# SciML Integration in AlgebraicAgents.jl

The integration can be loaded as:

```julia
using AlgebraicAgents
add_integration(:SciMLIntegration); using SciMLIntegration
```

```@meta
CurrentModule = SciMLIntegration
```

## Model, Integrator, and Solution Wrap Types

```@docs
DiffEqAgent
```

## Algebraic Bindings

```@docs
@get_oagent
```

## Observables

```@docs
push_in_observables!
push_out_observables!
```