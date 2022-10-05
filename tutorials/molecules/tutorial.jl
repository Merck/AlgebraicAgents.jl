using AlgebraicAgents
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
include("types.jl")

# define therapeutic areas
# a therapeutic area spans a discovery units and drug entities (molecules)
therapeutic_area1 = FreeAgent("therapeutic_area1")
therapeutic_area2 = FreeAgent("therapeutic_area2")

# join therapeutic models into a pharma model
pharma_model = ⊕(therapeutic_area1, therapeutic_area2; name="pharma_model")

# initialize and push discovery units to therapeutic areas
entangle!(therapeutic_area1, Discovery("dx", 5.2, 10.; dt=3.))
entangle!(therapeutic_area2, Discovery("dx", 6., 8.; dt=5.))

# add SDE models for drug demand in respective areas
using DifferentialEquations

dt = 1//2^(4); tspan = (0.0,100.)
f(u,p,t) = p[:α]*u; g(u,p,t) = p[:β]*u

prob_1 = SDEProblem(f,g,.9,tspan,Dict{Symbol, Any}(:α=>.01, :β=>.01))
prob_2 = SDEProblem(f,g,1.2,tspan,Dict{Symbol, Any}(:α=>.005, :β=>.02))

# provide integration of common SciML problem, integrator, and solution types
add_integration(:SciMLIntegration); using SciMLIntegration

demand_model_1 = DiffEqAgent("demand", prob_1, EM(); out_observables=Dict("demand" => 1), dt)
demand_model_2 = DiffEqAgent("demand", prob_2, EM(); out_observables=Dict("demand" => 1), dt)

# push market demand units to therapeutic areas
entangle!(therapeutic_area1, demand_model_1)
entangle!(therapeutic_area2, demand_model_2)

# extract parameters
getparameters(pharma_model)
# set parameters
set_parameters!(pharma_model, Dict("therapeutic_area1/demand" => Dict(:α=>.02, :β=>.02)))

#=
discovery units will adjust its productivity based on market demand:

# sync with market demand
dx.productivity, = @observables dx "../demand":"demand"
=#  

# let the problem evolve
simulate(pharma_model, 100)

# plot the results
## dynamic dispatch on agent types
draw(getagent(pharma_model, "therapeutic_area1/dx"))
draw(getagent(pharma_model, "therapeutic_area2/dx"))
draw(getagent(pharma_model, "therapeutic_area1/demand"))
draw(getagent(pharma_model, "therapeutic_area2/demand"))

# return a function which maps params to simulation results
# for optimization etc.
o = objective(pharma_model)

## get results given params
o(Dict("therapeutic_area1/demand" => Dict(:α=>.02, :β=>.02)))
## a bit more intricate example
using Statistics

N_samples = 100

o_avg = function (params)
  # return average number of surviving molecules
  mean(1:N_samples) do _
    df = getagent(o(params), "therapeutic_area1/dx").df_output
    df_ = combine(df, names(df) .=> sum)
    
    df_[1, "small_sum"] + df_[1, "large_sum"] - df_[1, "killed_sum"]
  end
end

@time o_avg(Dict("therapeutic_area1/demand" => Dict(:α=>.02, :β=>.02)))