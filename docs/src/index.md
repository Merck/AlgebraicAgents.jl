# API Documentation

```@meta
CurrentModule = AlgebraicAgents
```

## Algebraic agent types

```@docs
AbstractAlgebraicAgent
FreeAgent
```

## Implementing custom types

To implement a custom algebraic agent type, you may want to use the convenience macro [`@oagent`](@ref) which supplies type fields expected (not required, though) by the interface. 

Next step is to implement the required interface functions:

```@docs
AlgebraicAgents._step!(::AbstractAlgebraicAgent, ::Float64)
AlgebraicAgents._projected_to(::AbstractAlgebraicAgent)
AlgebraicAgents.getobservable(::AbstractAlgebraicAgent, ::Any)
```

For a deeper integration of the agent type, you may specialize the following functions:

```@docs
AlgebraicAgents._getparameters(::AbstractAlgebraicAgent)
AlgebraicAgents._set_parameters!(::AbstractAlgebraicAgent, ::Any)
AlgebraicAgents._draw(::AbstractAlgebraicAgent)
AlgebraicAgents._reinit!(::AbstractAlgebraicAgent)
AlgebraicAgents._interact!(::AbstractAlgebraicAgent)
AlgebraicAgents._prestep!(::AbstractAlgebraicAgent, ::Float64)
```

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
set_parameters!
```
### Accessors

```@docs
getobservable
gettimeobservable
```

### List observables observed by an agent and exported by an agent
```@docs
in_observables
out_observables
```

### Solving & plotting

```@docs
step!
simulate
draw
```

## Paths

Implements path-like structure of algebraic agents.

```@docs
@glob_str
@uuid_str
getagent
disentangle!
```

## Opera, a dynamic structure to facilitate complex interactions

```@docs
Opera
AbstractOperaCall
AgentCall
opera_enqueue!
```

## Operad

Defines general sums and products of algebraic models.

```@docs
⊕
@sum
```

## Agent types macros

Supports convenient algebraic agent subtyping.

```@docs
@oagent
```

## Walks

Walk algebraic agents' hierarchy.

```@docs
prewalk
postwalk
```

# Utility functions

### Add integration

```@docs
add_integration
```

### Expression wrappers

```@docs
@wrap
```

### Observable accessor, interaction schedulers

```@docs
@observables
@schedule
@schedule_call
```

### Flat representation

```@docs
flatten
```