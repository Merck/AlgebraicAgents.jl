# Required Libraries
using Revise
using AlgebraicAgents
using ReactiveDynamics
using DifferentialEquations
using Distributions, Plots, DataFrames, Random
##
# Define the structure of a cell
struct Cell
    # id::String
    cell_type::Symbol  # Normal or Cancer
    dynamical_state::Symbol  # Active or Inactive
end

# Define the structure of a place
struct Place
    id::String
    cells::Dict{Cell, Int}
end

# Define the structure for a stochastic transition
struct StochasticTransition
    id::String
    precondition::Function
    postcondition::Function
    rate_fn::Function
end


# Define the structure for an input arc
struct InputArc
    id::String
    source::Place
    target::StochasticTransition
    token_type::Cell
    multiplicity::Int
end

# Define the structure for an output arc
struct OutputArc
    id::String
    source::StochasticTransition
    target::Place
    token_type::Cell
    multiplicity::Int
end

# Define the structure of a generalized Petri net
struct GeneralizedPetriNet
    places::Vector{Place}
    transitions::Vector{StochasticTransition}
    marking::Dict{Place, Dict{Cell, Int}}
end

# Function to check if a transition can fire
function can_fire(t::StochasticTransition, gpn::GeneralizedPetriNet)
    all(input_arc -> gpn.marking[input_arc.source][input_arc.token_type] >=
                     input_arc.multiplicity, t.input_arcs)
end

# Function to execute a transition
function execute_transition(t::StochasticTransition,
                            gpn::GeneralizedPetriNet)
    if can_fire(t, gpn)
        # Consume tokens according to the input arcs
        for arc in t.input_arcs
            gpn.marking[arc.source][arc.token_type] -= arc.multiplicity
        end
        # Generate tokens according to the output arcs
        for arc in t.output_arcs
            gpn.marking[arc.target][arc.token_type] += arc.multiplicity
        end
    end
end

# # Function to update the Petri net
# function update_petri_net(gpn::GeneralizedPetriNet)
#     # Get all transitions that can fire
#     can_fire_transitions = [t for t in gpn.transitions if can_fire(t, gpn)]

#     # If there are no transitions that can fire, return
#     if isempty(can_fire_transitions)
#         return gpn
#     end

#     # If there are stochastic transitions, sort them by their rates
#     if any(t -> isa(t, StochasticTransition), can_fire_transitions)
#         sort!(can_fire_transitions, by = t -> isa(t, StochasticTransition) ? t.rate : 0,
#               rev = true)
#     end

#     # Attempt to fire each transition
#     for t in can_fire_transitions
#         # If the transition can still fire, execute it
#         if can_fire(t, gpn)
#             execute_transition(t, gpn)
#         end
#     end

#     return gpn
# end






# Updated function to calculate the weighted rate for each transition
function transition_rate(t::StochasticTransition, gpn::GeneralizedPetriNet)
    total_weight = 0
    total_rate = 0
    for arc in t.input_arcs
        cell_density = gpn.marking[arc.source][arc.token_type]
        total_rate += arc.multiplicity * cell_density
        total_weight += arc.multiplicity
    end
    # Ensure that we do not divide by zero
    if total_weight != 0
        return total_rate / total_weight
    else
        return 0
    end
en



# Define a function to update the Petri net
function update_petri_net!(gpn::GeneralizedPetriNet)
    can_fire_transitions = [t for t in gpn.transitions if can_fire(t, gpn)]
    if isempty(can_fire_transitions)
        return
    end
    # Order transitions based on their rates
    transition_rates = [t.rate for t in can_fire_transitions]
    probabilities = transition_rates ./ sum(transition_rates)
    selected_transition = sample(can_fire_transitions, Weights(probabilities))
    execute_transition!(selected_transition, gpn)
end



# Define a function to simulate the Petri net
function simulate_petri_net!(gpn::GeneralizedPetriNet, simulation_time::Int)
    for _ in 1:simulation_time
        update_petri_net!(gpn)
    end
end

















## simulation
# Simulation
active_normal_cell = Cell("ANC", :normal, :active)
inactive_normal_cell = Cell("INC", :normal, :inactive)
active_cancer_cell = Cell("ACC", :cancer, :active)
inactive_cancer_cell = Cell("ICC", :cancer, :inactive)

place1 = Place("P1", Dict(active_normal_cell => 10, inactive_normal_cell => 5, active_cancer_cell => 5, inactive_cancer_cell => 2))
place2 = Place("P2", Dict(active_normal_cell => 5, inactive_normal_cell => 10, active_cancer_cell => 10, inactive_cancer_cell => 3))
place3 = Place("P3", Dict(active_normal_cell => 8, inactive_normal_cell => 8, active_cancer_cell => 6, inactive_cancer_cell => 4))
place4 = Place("P4", Dict(active_normal_cell => 6, inactive_normal_cell => 6, active_cancer_cell => 8, inactive_cancer_cell => 4))

# Transition 1: An active cancer cell and an active normal cell react to create two active cancer cells.
input_arc1 = InputArc("IA1", place1, transition1, active_cancer_cell, 1)
input_arc2 = InputArc("IA2", place1, transition1, active_normal_cell, 1)
output_arc1 = OutputArc("OA1", transition1, place2, active_cancer_cell, 2)
transition1 = GeneralTransition("T1", [input_arc1, input_arc2])

# Transition 1: An active cancer cell and an active normal cell react to create two active cancer cells.
rate1 = gpn -> place_rate(gpn.places[1], active_cancer_cell, 0.1)  # rate function depends on the number of active cancer cells in P1
input_arc1 = InputArc("IA1", place1, transition1, active_cancer_cell, 1)
input_arc2 = InputArc("IA2", place1, transition1, active_normal_cell, 1)
output_arc1 = OutputArc("OA1", transition1, place2, active_cancer_cell, 2)
transition1 = StochasticTransition("T1", [input_arc1, input_arc2], rate1)




# Transition 2: An active cancer cell and an inactive normal cell react to create two active cancer cells.
input_arc3 = InputArc("IA3", place3, transition2, active_cancer_cell, 1)
input_arc4 = InputArc("IA4", place3, transition2, inactive_normal_cell, 1)
output_arc2 = OutputArc("OA2", transition2, place4, active_cancer_cell, 2)
transition2 = GeneralTransition("T2", [input_arc3, input_arc4])

gpn = GeneralizedPetriNet(
    [place1, place2, place3, place4],
    [transition1, transition2],
    [input_arc1, input_arc2, input_arc3, input_arc4],
    [output_arc1, output_arc2],
    Dict(place1 => place1.cells, place2 => place2.cells, place3 => place3.cells, place4 => place4.cells),
    zeros(Int, 4, 2)  # arc_multiplicity_matrix of size 4x2 as we have 4 places and 2 transitions
)

# Number of time steps
n_steps = 100

# Simulate the system for n_steps
for t in 1:n_steps
    update_petri_net(gpn)
end


# =================================================================
# Define the rate function for each transition
rate1 = gpn -> place_rate(gpn.places[1], active_cancer_cell, 0.1)
rate2 = gpn -> place_rate(gpn.places[3], active_cancer_cell, 0.2)
# Define the ODE system for the Petri net
function petri_net_ode(du, u, p, t)
    update_petri_net(p.gpn)
    du .= 0
    for i in 1:length(p.transitions)
        t = p.transitions[i]
        du[p.marking[t.source], i] -= t.rate(p.gpn)
        du[p.marking[t.target], i] += t.rate(p.gpn)
    end
end
# Set up the initial conditions for the ODE solver
u0 = zeros(Int, length(gpn.marking), length(gpn.transitions))
u0[1, 1] = 1  # initial marking for P1
# Set up the ODE problem and solver
tspan = (0.0, 10.0)
prob = ODEProblem(petri_net_ode, u0, tspan,
                  (gpn = gpn, transitions = [transition1, transition2],
                   marking = gpn.marking))
sol = solve(prob, Tsit5())
# Plot the results
using Plots
plot(sol, vars = 1:4, title = ["P1" "P2" "P3" "P4"], xlabel = "Time",
     ylabel = "Number of cells")

# =================================================================




## ==== visualization================================================
using Plots

function visualize_trajectory(gpn::GeneralizedPetriNet, n_steps::Int, cell_types::Vector{Cell})
    data = Dict() # This will hold the number of each cell type for each time step
    
    for cell_type in cell_types
        data[cell_type] = []
    end

    # Simulate the system for n_steps
    for t in 1:n_steps
        update_petri_net(gpn)
        # Store the number of each cell type
        for cell_type in cell_types
            push!(data[cell_type], sum([gpn.marking[place][cell_type] for place in gpn.places]))
        end
    end

    # Plot the number of each cell type over time
    p = plot()
    for cell_type in cell_types
        plot!(p, data[cell_type], label = "$(cell_type.cell_type) - $(cell_type.dynamical_state)")
    end
    title!(p, "Number of Cells Over Time")
    xlabel!(p, "Time")
    ylabel!(p, "Number of Cells")
    return p
end

# Define your cell types
cell_types = [active_normal_cell, inactive_normal_cell, active_cancer_cell, inactive_cancer_cell]

# Run the simulation and visualize the results
p = visualize_trajectory(gpn, 100, cell_types)

