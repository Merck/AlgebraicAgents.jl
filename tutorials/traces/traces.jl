using AlgebraicAgents
import Distributions: Poisson
import Random: randstring

# type system
include("types.jl")

# preclinical: orchestrates experiments; is a directory of candidate/accepted/rejected candidates
## reject (filter) queries
q = [f"""any(t -> (t.name == "assay_1") && (t.readout > .5), _.trace)"""]
preclinical = Preclinical("preclinical", 0., 1.; queries_reject=q)

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

# remove molecules with more than two parents
pharma_model |> @filter("length(_.path)>2") .|> disentangle!
# remove candidate molecules with more than two parents
pharma_model |> @filter("length(_.path)>2 && (_.decision_time === missing)") .|> disentangle!