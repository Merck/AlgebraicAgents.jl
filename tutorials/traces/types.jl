#=
declare type hierarchy of a toy preclinical development model:
 - overarching pharma model (FreeAgent),
 - discovery unit (emits drug candidates),
 - preclinical unit; orchestrates experiments, executes queries, 
 - assay; reduces uncertainty about candidate's activity but bears cost,
 - candidate molecule; undergoes experiments.
=#
using AlgebraicAgents

# candidate molecules
abstract type AbstractMolecule <: AbstractAlgebraicAgent end

# fingeprint size (chemical descriptor)
const N = 5
# if `belief ∉ [uncertainty_threshold, 1-uncertainty_threshold]`, terminate experiments
const uncertainty_threshold = 0.2
# in-silico belief 
const init_belief_generator = (r = rand(N); r ./ sum(r))

# candidate molecule; carries a scientist's belief about its activity
"Candidate molecule, parametrized by a chemical fingerprint."
@aagent FreeAgent AbstractMolecule struct Molecule
    birth_time::Float64
    decision_time::Union{Float64, Missing}

    fingerprint::NTuple{N, Float64}
    path::Vector{AbstractString}

    is_allocated::Bool

    belief::Float64
    trace::Vector{<:Any}
end

# preclinical experiments
abstract type AbstractAssay <: AbstractAlgebraicAgent end

# parametric experiment; updates belief about candidate's activity
"Parametric experiment, updates belief about candidate's activity."
@aagent FreeAgent AbstractAssay struct Assay
    duration::Float64
    cost::Float64
    capacity::Float64

    belief_model::NTuple{N, Float64}

    allocated::Vector{AlgebraicAgents.UUID}
    planned::Vector{AlgebraicAgents.UUID}

    t::Float64
    t0::Float64
end

## toy discovery unit - emits molecules with chemical fingerprints
@aagent struct Discovery
    rate::Float64 # expected number of mols per unit step

    t::Float64
    dt::Float64

    t0::Float64
end

## toy preclinical development model - orchestrates experiments, runs queries
"Toy discovery unit; emits molecules."
@aagent struct Preclinical
    queries_accept::Vector{AlgebraicAgents.AbstractQuery}
    queries_reject::Vector{AlgebraicAgents.AbstractQuery}

    total_costs::Float64

    perturb_rate::Float64 # expected number of perturbed mols (successors) born per a unit step

    t::Float64
    t0::Float64
    dt::Float64
end

# constructors
"Emit a candidate molecule."
function Molecule(mol, fingerprint, t, path = AbstractString[])
    Molecule(mol, t, missing, fingerprint, path, false, init_belief_from_fingerprint(i), [])
end

"Initialize a discovery unit, parametrized by molecule production rate."
function Discovery(name, rate, t = 0.0; dt = 2.0)
    Discovery(name, rate, t, dt, t0)
end

"Initialize an assay, parametrized by duration, cost, capacity, and a belief model."
function Assay(name, duration::Float64, cost::Float64, capacity::Float64,
               belief_model = tuple(rand(-1:1, 5)...), t = 0.0)
    Assay(name, duration, cost, capacity, belief_model,
          Vector{AlgebraicAgents.UUID}(undef, 0), Vector{AlgebraicAgents.UUID}(undef, 0),
          t, t)
end

"Initialize a preclinical unit comprising candidate molecules and parametrized by removal queries."
function Preclinical(name, perturb_rate::Float64, t = 0.0; dt = 1.0,
                     queries_accept = AlgebraicAgents.AbstractQuery[],
                     queries_reject = AlgebraicAgents.AbstractQuery[])
    p = Preclinical(name, queries_accept, queries_reject, 0.0, perturb_rate, t, t, dt)

    # candidates and accepted, rejected candidates
    entangle!(p, FreeAgent("candidates"))
    entangle!(p, FreeAgent("accepted"))
    entangle!(p, FreeAgent("rejected"))

    p
end

# implement common interface

## discovery
function AlgebraicAgents._step!(dx::Discovery, t)
    if t === dx.t
        # emit candidates
        for _ in 1:rand(Poisson(dx.rate * dx.dt))
            mol = Molecule(randstring(5), Tuple(rand(N)), t)
            entangle!(getagent(getparent(dx), "preclinical/candidates"), mol)
        end

        dx.t += dx.dt
    end

    dx.t
end

function AlgebraicAgents._reinit!(dx::Discovery)
    dx.t = dx.t0
    dx
end

AlgebraicAgents._projected_to(dx::Discovery) = dx.t

## candidate molecules
AlgebraicAgents._step!(::Molecule, _) = nothing
AlgebraicAgents._projected_to(mol::Molecule) = nothing
AlgebraicAgents._reinit!(mol::Molecule) = disentangle!(mol)

## assays
function AlgebraicAgents._step!(a::Assay, t)
    if t === a.t
        # update beliefs
        foreach(a.allocated) do uuid
            update_belief!(getagent(a, uuid), a)
            getagent(a, uuid).is_allocated = false
        end
        # empty schedule
        empty!(a.allocated)
        append!(a.allocated, a.planned)
        empty!(a.planned)

        a.t += a.duration
    end

    a.t
end

AlgebraicAgents._projected_to(a::Assay) = a.t

# empty schedule
AlgebraicAgents._reinit!(a::Assay) = empty!(a.allocated)

## belief updating
### output in-silico belief
function init_belief_from_fingerprint(mol::Molecule)
    mol.belief = init_belief_generator' * collect(mol.fingerprint)
end

### update belief (in vitro/vivo), update trace
function update_belief!(mol::Molecule, assay::Assay)
    # dummy readout
    push!(mol.trace, (; name = getname(assay), readout = rand(), t = assay.t))
    # shift, clamp belief
    mol.belief = clamp(mol.belief + collect(assay.belief_model)' * collect(mol.fingerprint),
                       0, 1)

    mol
end

### information measure
function uncertainty_reduction(mol::Molecule, assay::Assay)
    abs(collect(assay.belief_model)' * collect(mol.fingerprint))
end

## preclinical units
function AlgebraicAgents._step!(a::Preclinical, t)
    if t === a.t
        # candidate molecules - filter out based on beliefs
        # based on beliefs, accept or reject candidates
        for c in values(inners(getagent(a, "candidates")))
            if c.belief <= uncertainty_threshold
                entangle!(getagent(a, "rejected"), disentangle!(c))
                c.decision_time = t
            elseif c.belief >= 1 - uncertainty_threshold
                entangle!(getagent(a, "accepted"), disentangle!(c))
                c.decision_time = t
            elseif length(c.trace) == length(inners(inners(a)["assays"]))
                entangle!(getagent(a, "rejected"), disentangle!(c))
                c.decision_time = t
            end
        end
        # now for queries - accept
        accept = []
        for q in a.queries_accept
            append!(accept, filter(collect(values(inners(getagent(a, "candidates")))), q))
        end
        for c in accept
            entangle!(getagent(a, "accepted"), disentangle!(c))
            c.decision_time = t
        end
        # queries - reject
        reject = []
        for q in a.queries_reject
            append!(accept, filter(collect(values(inners(getagent(a, "candidates")))), q))
        end
        for c in reject
            entangle!(getagent(a, "rejected"), disentangle!(c))
            c.decision_time = t
        end

        # schedule experiments
        all_assays = collect(values(inners(getagent(a, "assays"))))
        for c in values(inners(getagent(a, "candidates")))
            c.is_allocated && continue
            previous_assays = map(x -> x.name, c.trace)
            assays_available = filter(all_assays) do x
                (length(x.planned) < x.capacity) && (getname(x) ∉ previous_assays)
            end

            if !isempty(assays_available)
                option = argmin(assays_available) do assay
                    assay.cost / uncertainty_reduction(c, assay)
                end

                push!(option.planned, getuuid(c))
                c.is_allocated = true
                a.total_costs += option.cost
            end
        end

        # add perturbed candidates (from accepted)
        if !isempty(inners(getagent(a, "accepted")))
            for c in rand(collect(values(inners(getagent(a, "accepted")))),
                          rand(Poisson(a.dt * a.perturb_rate)))
                mol = Molecule(randstring(5), c.fingerprint .+ 0.1 .* Tuple(rand(N)), t,
                               [c.path; "parent_$(rand(1:2))"; c.name])
                entangle!(getagent(a, "candidates"), mol)
            end
        end
        a.t += a.dt
    end

    a.t
end

AlgebraicAgents._projected_to(a::Preclinical) = a.t

# empty schedule
AlgebraicAgents._reinit!(a::Assay) = (a.t = a.t0; a.total_costs = 0.0)
