# AlgebraicAgents.jl

*A Julia framework for the hierarchical, heterogeneous co-integration of
dynamical systems.*

AlgebraicAgents.jl lets you compose differential equations, discrete-event systems, and agent-based models within a single rooted hierarchy. Subsystems evolve at their own pace — the framework keeps them in sync through a minimal stepping interface — and may freely observe or interact with one another.

- **Multi-formalism.** Couple ODEs/SDEs, discrete-event systems, and
  agent-based models in a single simulation.
- **Hierarchical.** Organize subsystems into a tree, reference them by
  filesystem-like paths, and compose them with a structural sum `⊕`.
- **Extensible.** Wrap a custom solver or a third-party integrator as an agent
  by implementing two interface methods: [`AlgebraicAgents._step!`](@ref) and
  [`AlgebraicAgents._projected_to`](@ref).
- **Introspective.** Declare information flows between agents as *wires*,
  associate agents with atemporal *concepts* and typed *relations*, and
  visualize the resulting architecture.

## Installation

AlgebraicAgents.jl is registered in the Julia General registry, so it can be installed with Julia's built-in package manager [Pkg.jl](https://pkgdocs.julialang.org/v1/managing-packages/#Adding-packages):

```julia
using Pkg
Pkg.add("AlgebraicAgents")
```

Third-party integrations (DifferentialEquations.jl, Agents.jl,
AlgebraicDynamics.jl) load automatically once the corresponding package is
available in your environment — see [Integrations](integrations.md).

## Intended Audience

AlgebraicAgents.jl is intended for Julia modelers composing heterogeneous
dynamical systems across modeling formalisms — users of ecosystems and
frameworks such as SciML, Agents.jl, and AlgebraicDynamics.jl coupling
existing models, and practitioners wrapping models built outside these
frameworks. Primary applications lie in pharmaceutical value-chain modeling,
systems biology, and multi-physics engineering.

## A Minimal Example

A custom agent type is declared with the [`@aagent`](@ref) macro and given an
evolution rule by extending [`AlgebraicAgents._step!`](@ref):

```julia
using AlgebraicAgents

@aagent struct InventoryAgent
    stock_level::Int
    reorder_time::Int
end

AlgebraicAgents._step!(a::InventoryAgent) = (a.stock_level -= 1)
AlgebraicAgents._projected_to(a::InventoryAgent) = a.reorder_time
```

Existing solver objects from the SciML ecosystem can be wrapped directly:

```julia
using AlgebraicAgents, DifferentialEquations

wrap_system("my_model", ODEProblem((u, p, t) -> 1.01*u, [0.5], (0.0, 10.0)))
```

Agents are composed into a hierarchy with [`entangle!`](@ref) / [`⊕`](@ref)
and simulated with [`simulate`](@ref). See the
[Sketches](sketches/molecules/molecules.md) for fully worked examples, and
[Framework design](design_mmd.md) for the underlying simulation loop.

## Where to Go Next

- [Framework design](design_mmd.md) — the simulation loop, Opera, and
  hierarchy semantics.
- [Integrations](integrations.md) — built-in wrappers for
  DifferentialEquations.jl, Agents.jl, and AlgebraicDynamics.jl.
- **Sketches** — worked examples covering custom agents, SciML coupling,
  agent-based models, stochastic simulation, and relations.
- [API Reference](api.md) — the complete interface.
- [Contributing](contributing.md) — how to contribute to the core framework
  or add new integrations.

## Citation and License

AlgebraicAgents.jl is distributed under the MIT License. If you use it in
academic work, please cite the accompanying JOSS paper (see the repository's
`paper/` directory and the project's
[README](https://github.com/Merck/AlgebraicAgents.jl#readme) for current
citation details).
