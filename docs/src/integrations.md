# Integrations

## How integrations are loaded

Integrations of [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl), [Agents.jl](https://github.com/JuliaDynamics/Agents.jl), and [AlgebraicDynamics.jl](https://github.com/AlgebraicJulia/AlgebraicDynamics.jl) ship as Julia *package extensions* (see [Conditional loading of code in packages](https://pkgdocs.julialang.org/v1/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions))). The `AlgebraicAgents` `Project.toml` declares each third-party package under `[weakdeps]` and pairs it with an extension module under `[extensions]`; Pkg loads the extension automatically once *all* of its trigger packages are available and imported in the active session — there is nothing to opt into:

```julia
using AlgebraicAgents, DifferentialEquations
wrap_system("my_model", ODEProblem((u, p, t) -> 1.01*u, [0.5], (0.0, 10.0)))
```

The agent types (`DiffEqAgent`, `ABMAgent`/`AAgent`, `GraphicalAgent`) are exported from the main module so they can be referenced as field types or in dispatch even before the third-party package is loaded; their constructors and stepping logic become callable once the corresponding extension fires. Plotting is gated the same way: load `Plots` (and `DataFrames`, where applicable) and `draw` will start producing figures.

A few combinations require *multiple* triggers — e.g. converting an AlgebraicDynamics `GraphicalAgent` into a `DiffEqAgent` requires both `AlgebraicDynamics` and `DifferentialEquations`, and `@draw_df` requires both `DataFrames` and `Plots`. The full list of triggers is the `[extensions]` table in the package's `Project.toml`.

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