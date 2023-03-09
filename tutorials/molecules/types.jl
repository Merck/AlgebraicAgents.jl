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


