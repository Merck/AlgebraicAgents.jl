using AlgebraicAgents
import Distributions: Poisson
import Random: randstring
using MacroTools

# type system
include("types.jl")
# successor queries
include("successor_queries.jl")

# preclinical: wraps candidates/rejected/accepted molecules, schedules experiments
## (filter) queries - candidate rejection
q = [f"""any(t -> (t.name == "assay_1") && (t.readout > .5), _.trace)"""]
preclinical = Preclinical("preclinical", 3.0; queries_reject = q)

## add assays: first a directory of assays (free agent)
superassay = entangle!(preclinical, FreeAgent("assays"))
N_assays = 5;
for i in 1:N_assays
    entangle!(superassay, Assay("assay_$i", rand(1.0:5.0), 10e3 * rand(), rand(10.0:20.0)))
end;

# discovery: emits candidate molecules
discovery = Discovery("discovery", 3.0)

# overarching model
pharma_model = ⊕(preclinical, discovery; name = "pharma_model")

# let the problem evolve
simulate(pharma_model, 100)

# queries
## successor query
i = 2;
filter(pharma_model, p"""_ ≺ "parent_$($i)" """);
pharma_model |> @filter(p"""_ ≺ "parent_$($i)" """)

## simple queries
### molecules with more than two parents
i = 2;
pharma_model |> @filter(f"length(_.path)>$i");
### remove candidate molecules with more than two parents
pharma_model |> @filter(length(_.path)>$i) |> @filter(_.decision_time===missing) .|>
disentangle!
