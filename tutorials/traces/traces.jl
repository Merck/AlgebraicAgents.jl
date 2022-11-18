using AlgebraicAgents
import Distributions: Poisson
import Random: randstring
using MacroTools

# type system
include("types.jl")
# successor queries
include("successors_queries.jl")

# preclinical: orchestrates experiments; is a directory of candidate/accepted/rejected candidates
## reject (filter) queries
q = [f"""any(t -> (t.name == "assay_1") && (t.readout > .5), _.trace)"""]
preclinical = Preclinical("preclinical", 3.; queries_reject=q)

## add assays: assay directory firs
superassay = entangle!(preclinical, FreeAgent("assays"))
N_assays = 5; for i in 1:N_assays
    entangle!(superassay, Assay("assay_$i", rand(1.:5.), 10e3*rand(), rand(10.:20.)))
end

# discovery: emits candidate molecules
discovery = Discovery("discovery", 3.)

# overarching model
pharma_model = ⊕(preclinical, discovery; name="pharma_model")

# let the problem evolve
simulate(pharma_model, 100)

# queries
## successor query
i = 2; filter(pharma_model, p"""_ ≺ "parent_$($i)" """)
pharma_model |> @filter(p"""_ ≺ "parent_$($i)" """)

## simple queries
### molecules with more than two parents
i = 2; pharma_model |> @filter(f"length(_.path)>$i")
### remove candidate molecules with more than two parents
pharma_model |> @filter(length(_.path)>$i) |> @filter(_.decision_time === missing) .|> disentangle!