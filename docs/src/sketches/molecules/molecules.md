```@meta
EditURL = "<unknown>/../tutorials/molecules/molecules.jl"
```

# A Toy Pharma Model

We implement a toy pharma model. To that end, we have the following type hierarchy:

 - overarching **pharma model** (represented by a `FreeAgent` span type),
 - **therapeutic area** (represented by a `FreeAgent`),
 - **molecules** (small, large - to demonstrate dynamic dispatch; alternatively, marketed drugs; a drug may drop out from the system),
 - **discovery unit** (per therapeutic area); these generate new molecules according to a Poisson counting process,
 - **market demand**; this will be represented by a stochastic differential equation implemented in [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl).

## Agent Types

We define the type system and supply the stepping functions.

````@example molecules
using AlgebraicAgents

using DataFrames
using Distributions, Random
using Plots

# type hierarchy
"Drug entity, lives in a therapeutic area."
abstract type Molecule <: AbstractAlgebraicAgent end

# molecule params granularity
const N = 3;

# drug entity, lives in a therapeutic area
"Parametrized drug entity, lives in a therapeutic area."
@aagent FreeAgent Molecule struct SmallMolecule
    age::Float64
    birth_time::Float64
    time_removed::Float64

    mol::AbstractString
    profile::NTuple{N, Float64}

    sales::Float64
    df_sales::DataFrame
end
````

Note the use of a conveniency macro `@aagent` which appends additional fields expected (not required, though) by default interface methods.

We proceed with other agent types.

````@example molecules
# drug entity, lives in a therapeutic area
@doc (@doc SmallMolecule)
@aagent FreeAgent Molecule struct LargeMolecule
    age::Float64
    birth_time::Float64
    time_removed::Float64

    mol::AbstractString
    profile::NTuple{N, Float64}

    sales::Float64
    df_sales::DataFrame
end

# toy discovery unit - outputs small/large molecules to a given therapeutic area
"Toy discovery unit; outputs small and large molecules."
@aagent struct Discovery
    rate_small::Float64
    rate_large::Float64
    discovery_intensity::Float64

    t::Float64
    dt::Float64

    t0::Float64

    removed_mols::Vector{Tuple{String, Float64}}

    df_output::DataFrame
end

# `Discovery` constructor
"Initialize a discovery unit, parametrized by small/large molecules production rate."
function Discovery(name, rate_small, rate_large, t = 0.0; dt = 2.0)
    df_output = DataFrame(time = Float64[], small = Int[], large = Int[], removed = Int[])

    Discovery(name, rate_small, rate_large, 0.0, t, dt, t, Tuple{String, Float64}[],
              df_output)
end
````

## Stepping Functions

Next we provide an evolutionary law for the agent types. This is done by extending the interface function [`AlgebraicAgents._step!`](@ref).

````@example molecules
# Return initial sales volume of a molecule.
function sales0_from_params end

const sales0_factor_small = rand(N)
const sales0_factor_large = rand(N)

# dispatch on molecule type
sales0_from_params(profile) = 10^3 * (1 + collect(profile)' * sales0_factor_small)
sales0_from_params(profile) = 10^5 * (1 + collect(profile)' * sales0_factor_large)

const sales_decay_small = 0.9
const sales_decay_large = 0.7

# implement evolution
function AlgebraicAgents._step!(mol::SmallMolecule)
    t = projected_to(mol)
    push!(mol.df_sales, (t, mol.sales))
    mol.age += 1
    mol.sales *= sales_decay_small

    if (mol.sales <= 10) || (rand() >= exp(-0.2 * mol.age))
        mol.time_removed = t
        push!(getagent(mol, "../dx").removed_mols, (mol.mol, t))

        # move to removed candidates
        rm_mols = getagent(mol, "../removed-molecules")
        disentangle!(mol)
        entangle!(rm_mols, mol)
    end
end

# implement common interface"
# molecules"
function AlgebraicAgents._step!(mol::LargeMolecule)
    t = projected_to(mol)
    push!(mol.df_sales, (t, mol.sales))

    mol.age += 1
    mol.sales *= sales_decay_large

    if (mol.sales <= 10) || (rand() >= exp(-0.3 * mol.age))
        mol.time_removed = t
        push!(getagent(mol, "../dx").removed_mols, (mol.mol, t))

        # move to removed candidates
        rm_mols = getagent(mol, "../removed-molecules")
        disentangle!(mol)
        entangle!(rm_mols, mol)
    end
end

# discovery
function AlgebraicAgents._step!(dx::Discovery)
    t = projected_to(dx)
    # sync with market demand
    dx.discovery_intensity, = @observables dx "../demand":"demand"
    ν = dx.discovery_intensity * dx.dt
    small, large = rand(Poisson(ν * dx.rate_small)), rand(Poisson(ν * dx.rate_large))
    removeed = 0
    ix = 1
    while ix <= length(dx.removed_mols)
        if (dx.removed_mols[ix][2] < t)
            removeed += 1
            deleteat!(dx.removed_mols, ix)
        else
            ix += 1
        end
    end
    push!(dx.df_output, (t, small, large, removeed))

    for _ in 1:small
        mol = release_molecule(randstring(5), Tuple(rand(N)), t, SmallMolecule)
        entangle!(getparent(dx), mol)
    end

    for _ in 1:large
        mol = release_molecule(randstring(5), Tuple(rand(N)), t, LargeMolecule)
        entangle!(getparent(dx), mol)
    end

    dx.t += dx.dt
end

"Initialize a new molecule."
function release_molecule(mol, profile, t, ::Type{T}) where {T <: Molecule}
    T(mol, 0.0, t, Inf, mol, profile, sales0_from_params(profile),
      DataFrame(time = Float64[], sales = Float64[]))
end
````

We provide additional interface methods, such as [`AlgebraicAgents._reinit!`](@ref) and [`AlgebraicAgents._projected_to`](@ref).

````@example molecules
AlgebraicAgents._reinit!(mol::Molecule) = disentangle!(mol)

function AlgebraicAgents._reinit!(dx::Discovery)
    dx.t = dx.t0
    dx.discovery_intensity = 0.0
    empty!(dx.df_output)

    dx
end

function AlgebraicAgents._projected_to(mol::Molecule)
    if mol.time_removed < Inf
        # candidate removed, do not step further
        true
    else
        mol.age + mol.birth_time
    end
end

AlgebraicAgents._projected_to(dx::Discovery) = dx.t
````

We may also provide a custom plotting recipe. As the internal log is modeled as a DataFrame, we want to use [`AlgebraicAgents.@draw_df`](@ref) convenience macro.

````@example molecules
# implement plots
AlgebraicAgents.@draw_df Discovery df_output
````

## Model Instantiation

Next step is to instantiate a dynamical system.

````@example molecules
# define therapeutic areas
therapeutic_area1 = FreeAgent("therapeutic_area1")
therapeutic_area2 = FreeAgent("therapeutic_area2")

# join therapeutic models into a pharma model
pharma_model = ⊕(therapeutic_area1, therapeutic_area2; name="pharma_model")

# initialize and push discovery units to therapeutic areas
# discovery units evolve at different pace
entangle!(therapeutic_area1, Discovery("dx", 5.2, 10.; dt=3.))
entangle!(therapeutic_area2, Discovery("dx", 6., 8.; dt=5.))
# log removed candidates
entangle!(therapeutic_area1, FreeAgent("removed-molecules"))
entangle!(therapeutic_area2, FreeAgent("removed-molecules"))
````

### Integration with SciML

Let's define toy market demand model and represent this as a stochastic differential equation defined in `DifferentialEquations.jl`

````@example molecules
# add SDE models for drug demand in respective areas
using DifferentialEquations

dt = 1//2^(4); tspan = (0.0,100.)
f(u,p,t) = p[1]*u; g(u,p,t) = p[2]*u

prob_1 = SDEProblem(f,g,.9,tspan,[.01, .01])
prob_2 = SDEProblem(f,g,1.2,tspan,[.01, .01])
````

Internally, a discovery unit will adjust the candidate generating process intensity according to the observed market demand:

````@example molecules
# add SDE models for drug demand in respective areas
demand_model_1 = DiffEqAgent("demand", prob_1, EM(); exposed_ports=Dict("demand" => 1), dt)
demand_model_2 = DiffEqAgent("demand", prob_2, EM(); exposed_ports=Dict("demand" => 1), dt)

# push market demand units to therapeutic areas
entangle!(therapeutic_area1, demand_model_1)
entangle!(therapeutic_area2, demand_model_2)

# sync with market demand
@observables first(by_name(pharma_model, "dx")) "../demand":"demand"
````

Let's inspect the composite model:

````@example molecules
# show the model
pharma_model
````

````@example molecules
getagent(pharma_model, glob"therapeutic_area?/")
````

## Simulating the System

Let's next evolve the composite model over a hundred time units. The last argument is optional here; see `?simulate` for the details.

````@example molecules
# let the problem evolve
simulate(pharma_model, 100)

getagent(pharma_model, "therapeutic_area1/dx")

getagent(pharma_model, "therapeutic_area1/demand")
````

## Plotting

We draw the statistics of a Discovery unit in Therapeutic Area 1:

````@example molecules
draw(getagent(pharma_model, "therapeutic_area1/dx"))
````

## Queries

Let's now query the simulated system.

To find out which molecules were discovered after time `t=10` and removed from the track before time `t=30`, write

````@example molecules
pharma_model |> @filter(_.birth_time > 10 && _.time_removed < 30)
````

Equivalently, we could make use of f(ilter)-strings, see [`@f_str`](@ref), and write

````@example molecules
from = 10; to = 30
pharma_model |> @filter(f"_.birth_time > $from && _.time_removed < $to");
nothing #hide
````

Let's investigate the average life time:

````@example molecules
# get molecules already removed from the system
removed_molecules = pharma_model |> @filter(f"_.time_removed < Inf")
# calculate `time_removed - birth_time`
# we iterate over `removed_molecules`, and apply the (named) transform function on each agent
# a given agent is referenced to as `_`
life_times = removed_molecules |> @transform(area = getname(getagent(_, "../..")), time=(_.time_removed - _.birth_time))

using Statistics: mean
avg_life_time = mean(x -> x.time, life_times)
````

