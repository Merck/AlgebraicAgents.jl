#= 
declare type hierachy of a toy pharma model:
 - pharma model (represented by a FreeAgent),
 - therapeutic area (represented by a FreeAgent), 
 - molecules (small, large - to demonstrate dynamic dispatch)
   alternatively, marketed drugs; a drug may drop out from the system,
 - discovery unit (per therapeutic area)
   generates new molecules according to a Poisson counting process
 - market demand
   this will be represented by a stochastic differential equation implemented in DifferentialEquations.jl
=#
using AlgebraicAgents

using DataFrames
using Distributions, Random
using Plots

# type hierarchy
"Drug entity, lives in a therapeutic area."
abstract type Molecule <: AbstractAlgebraicAgent end

const N = 3 # molecule params granularity

## drug entity, lives in a therapeutic area 
"Parametrized drug entity, lives in a therapeutic area."
@aagent FreeAgent Molecule struct SmallMolecule
    age::Float64
    birth_time::Float64
    kill_time::Float64

    mol::AbstractString
    profile::NTuple{N, Float64}

    sales::Float64
    df_sales::DataFrame
end

## drug entity, lives in a therapeutic area
@doc (@doc SmallMolecule)
@aagent FreeAgent Molecule struct LargeMolecule
    age::Float64
    birth_time::Float64
    kill_time::Float64

    mol::AbstractString
    profile::NTuple{N, Float64}

    sales::Float64
    df_sales::DataFrame
end

## toy discovery unit - outputs small/large molecules
## to a given therapeutic area
@aagent struct Discovery
    rate_small::Float64
    rate_large::Float64
    productivity::Float64

    t::Float64
    dt::Float64

    t0::Float64

    removed_mols::Vector{Tuple{String, Float64}}

    df_output::DataFrame
end

@doc "Toy discovery unit; outputs small and large molecules." Discovery

# constructors
"Initialize a discovery unit, parametrized by small/large molecules production rate."
function Discovery(name, rate_small, rate_large, t = 0.0; dt = 2.0)
    df_output = DataFrame(time = Float64[], small = Int[], large = Int[], removed = Int[])

    Discovery(name, rate_small, rate_large, 0.0, t, dt, t, Tuple{String, Float64}[],
              df_output)
end

"Return initial sales volume of a molecule."
function sales0_from_params end

const sales0_factor_small = rand(N)
const sales0_factor_large = rand(N)

# dispatch on molecule type
sales0_from_params(profile) = 10^3 * (1 + collect(profile)' * sales0_factor_small)
sales0_from_params(profile) = 10^5 * (1 + collect(profile)' * sales0_factor_large)

const sales_decay_small = 0.9
const sales_decay_large = 0.7

# implement evolution
function AlgebraicAgents._step!(mol::SmallMolecule, t)
    if t === (mol.age + mol.birth_time)
        push!(mol.df_sales, (t, mol.sales))
        mol.age += 1
        mol.sales *= sales_decay_small

        if (mol.sales <= 10) || (rand() >= exp(-0.2 * mol.age))
            mol.kill_time = t
            push!(getagent(mol, "../dx").removed_mols, (mol.mol, t))
            disentangle!(mol)
        end
    end

    mol.age + mol.birth_time
end

# implement common interface
## molecules
function AlgebraicAgents._step!(mol::LargeMolecule, t)
    if t === (mol.age + mol.birth_time)
        push!(mol.df_sales, (t, mol.sales))

        mol.age += 1
        mol.sales *= sales_decay_large

        if (mol.sales <= 10) || (rand() >= exp(-0.3 * mol.age))
            mol.kill_time = t
            push!(getagent(mol, "../dx").removed_mols, (mol.mol, t))
            disentangle!(mol)
        end
    end

    mol.age + mol.birth_time
end

AlgebraicAgents._reinit!(mol::Molecule) = disentangle!(mol)

AlgebraicAgents._projected_to(mol::Molecule) = mol.age + mol.birth_time

## discovery
function AlgebraicAgents._step!(dx::Discovery, t)
    if t === dx.t
        # sync with market demand
        dx.productivity, = @observables dx "../demand":"demand"
        ν = dx.productivity * dx.dt
        small, large = rand(Poisson(ν * dx.rate_small)), rand(Poisson(ν * dx.rate_large))
        killed = 0
        ix = 1
        while ix <= length(dx.removed_mols)
            if (dx.removed_mols[ix][2] < t)
                killed += 1
                deleteat!(dx.removed_mols, ix)
            else
                ix += 1
            end
        end
        push!(dx.df_output, (t, small, large, killed))

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

    dx.t
end

function AlgebraicAgents._reinit!(dx::Discovery)
    dx.t = dx.t0
    dx.productivity = 0.0
    empty!(dx.df_output)

    dx
end

"Initialize a new molecule."
function release_molecule(mol, profile, t, ::Type{T}) where {T <: Molecule}
    T(mol, 0.0, t, Inf, mol, profile, sales0_from_params(profile),
      DataFrame(time = Float64[], sales = Float64[]))
end

AlgebraicAgents._projected_to(dx::Discovery) = dx.t

# implement plots
AlgebraicAgents.@draw_df Discovery df_output
