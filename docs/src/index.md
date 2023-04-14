# API Documentation

```@meta
CurrentModule = AlgebraicAgents
```

## Agent types

```@docs
AbstractAlgebraicAgent
FreeAgent
FreeAgent(::AbstractString, ::Vector{<:AbstractAlgebraicAgent})
```

## Implementing custom types

To implement a custom agent type, you may want to use the convenience macro [`@aagent`](@ref) which supplies type fields expected (not required, though) by the interface.

### Required methods

```@docs
AlgebraicAgents._step!(::AbstractAlgebraicAgent)
AlgebraicAgents._projected_to(::AbstractAlgebraicAgent)
```

### Optional methods

```@docs
AlgebraicAgents._getparameters(::AbstractAlgebraicAgent)
AlgebraicAgents._setparameters!(::AbstractAlgebraicAgent, ::Any)
AlgebraicAgents._draw(::AbstractAlgebraicAgent)
AlgebraicAgents._reinit!(::AbstractAlgebraicAgent)
AlgebraicAgents._interact!(::AbstractAlgebraicAgent)
AlgebraicAgents._prestep!(::AbstractAlgebraicAgent, ::Float64)
```

Other optional methods include
 - [`getobservable(::AbstractAlgebraicAgent, ::Any)`](@ref)
 - [`observables(::AbstractAlgebraicAgent)`](@ref)
 - [`wrap_system`](@ref)
 - [`extract_agent`](@ref)

## Loading third-party package integrations

So far, integrations of [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl), [Agents.jl](https://github.com/JuliaDynamics/Agents.jl), and [AlgebraicDynamics.jl](https://github.com/AlgebraicJulia/AlgebraicDynamics.jl) are provided.

Loading of the integrations is facilitated by [Requires.jl](https://github.com/JuliaPackaging/Requires.jl); the integration will automatically be included once the respective third-party package is loaded.

For example,

```@example
using AlgebraicAgents
@isdefined DiffEqAgent
```

```@example
using AlgebraicAgents, DifferentialEquations
@isdefined DiffEqAgent
wrap_system("my_model", ODEProblem((u, p, t) -> 1.01*u, [1/2], (0., 10.)))
```

For plotting, you will want to load `Plots` as well. Nevertheless, function `draw` will inform you when necessary.

## Common interface

### Agent properties accessors

```@docs
getname
getuuid
getparent
inners
getopera
getdirectory
getparameters
setparameters!
```
### Observables

```@docs
observables
getobservable
gettimeobservable
```

### Solving & plotting

```@docs
step!
simulate
draw
```

### Paths

Implements path-like structure of agents.

```@docs
@glob_str
@uuid_str
getagent
by_name
```

### Opera, a dynamic structure to facilitate complex interactions

```@docs
Opera
poke
@call
add_instantious!
@future
add_future!
@control
add_control!
```

### Operations

Defines sums of agents.

```@docs
⊕
@sum
```

Entangle and disentangle agents hierarchies.

```@docs
entangle!
disentangle!
```

### Agent type constructors

Supports convenient agent subtyping.

```@docs
@aagent
```

To provide custom specialization of [`@aagent`](@ref) convenience macros, see [`AlgebraicAgents.define_agent`](@ref).

```@docs
AlgebraicAgents.define_agent
```

### Walks

Walk agents' hierarchy.

```@docs
prewalk
postwalk
prewalk_ret
postwalk_ret
```

## Utility functions

### Wrap a dynamical system, extract agent wrap

```@docs
wrap_system
extract_agent
```

### Flat representation

```@docs
flatten
```

### Default plots for custom agent types

```@docs
@draw_df
```

### Helper functions for Mermaid diagrams

```@docs
typetree_mmd
agent_hierarchy_mmd
```

## Queries

It is possible to run filter and transform queries on agent hierarchies.

### Filter queries

```@docs
FilterQuery
@f_str
@filter
AlgebraicAgents.filter(::AbstractAlgebraicAgent, ::FilterQuery)
```

To provide custom filter query types, you need to implement [`AlgebraicAgents._filter`](@ref) low-level matching method.

```@docs
AlgebraicAgents._filter
```

### Transform queries

```@docs
TransformQuery
@transform
transform
```