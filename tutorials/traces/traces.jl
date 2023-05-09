# type system
include("types.jl")

# initial date
t0 = Date("1-1-2020", dateformat"dd-mm-yyyy")

# preclinical: wraps candidates/rejected/accepted molecules, schedules experiments
## (filter) queries - candidate rejection
q = AlgebraicAgents.AbstractQuery[f"""any(t -> (t.name == "assay_1") && (t.readout > .5), _.trace)"""]
preclinical = Preclinical("preclinical", 3.0, t0; queries_reject = q)

## add assays: first a directory of assays (free agent)
superassay = entangle!(preclinical, FreeAgent("assays"))
N_assays = 5;
for i in 1:N_assays
    entangle!(superassay, Assay("assay_$i", Week(rand([1, 2, 3])), 10e3 * rand(), rand(10.0:20.0), t0))
end;

# discovery: emits candidate molecules
discovery = Discovery("discovery", 3.0, t0)

# overarching model
pharma_model = ⊕(preclinical, discovery; name = "pharma_model")

# let the problem evolve
simulate(pharma_model, t0 + Week(50))

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