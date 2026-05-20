# Integrations

## How integrations are loaded

Integrations with [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl), [Agents.jl](https://github.com/JuliaDynamics/Agents.jl), and [AlgebraicDynamics.jl](https://github.com/AlgebraicJulia/AlgebraicDynamics.jl) are provided as Julia *package extensions* (see [Conditional loading of code in packages](https://pkgdocs.julialang.org/v1/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions))). Each third-party package is declared under `[weakdeps]` in AlgebraicAgents's `Project.toml` and paired with an extension module under `[extensions]`. An extension is loaded automatically once *all* of its trigger packages have been loaded in the current session.

```julia
using AlgebraicAgents, DifferentialEquations
wrap_system("my_model", ODEProblem((u, p, t) -> 1.01*u, [0.5], (0.0, 10.0)))
```

The agent types (`DiffEqAgent`, `ABMAgent`/`AAgent`, `GraphicalAgent`) are exported from the main module, so they can be referenced as field types or in method dispatch even before the corresponding extension is loaded. Their constructors and stepping logic become available once the relevant extension is active. Plotting follows the same pattern: once `Plots` is loaded (along with `DataFrames` where applicable), `draw` can be used to produce figures.

Some functionality requires *multiple* trigger packages. For example, converting an AlgebraicDynamics `GraphicalAgent` into a `DiffEqAgent` requires both `AlgebraicDynamics` and `DifferentialEquations`, and `@draw_df` requires both `DataFrames` and `Plots`. The complete list of triggers for each extension is given by the `[extensions]` table in the package's `Project.toml`.

## SciML Integration

### Agent Constructors

```@docs
DiffEqAgent
```

## AlgebraicDynamics.jl Integration

## Agent Constructors

```@docs
GraphicalAgent
```

### Conversion to `DiffEqAgent`

```@docs
DiffEqAgent(::GraphicalAgent, args...)
```

### Sums

```@docs
⊕(::GraphicalAgent)
```

## Agents.jl Integration

The integration can be loaded as:

## Agent Constructors

```@docs
ABMAgent
AAgent
```

### Bindings

```@docs
@a
```