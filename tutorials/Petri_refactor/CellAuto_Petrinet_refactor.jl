using Distributions, StatsBase

# Define the places
places = ["P1", "P2", "P3"]

# Define the transitions
transitions = ["T1", "T2", "T3"]

# Define the token types
token_types = ["TokenA", "TokenB", "TokenC"]

# Define the arc multiplicity matrix
#! this can be essentially determine by the stoichiometric formula from catalyst.jl or reactive_dynamics 
# TODO:
arc_multiplicity = [2 0 1;
                    1 1 0;
                    0 2 1]

# Define the token counts for each place and token type
token_counts = Dict("P1" => Dict("TokenA" => 3, "TokenB" => 2, "TokenC" => 1),
                    "P2" => Dict("TokenA" => 1, "TokenB" => 2, "TokenC" => 3),
                    "P3" => Dict("TokenA" => 2, "TokenB" => 1, "TokenC" => 3))

# Create the tensor with the specified dimensions
# This function takes in arc_multiplicity, places, transitions and token_types as inputs, and returns a 3D tensor of integers.
# arc_multiplicity: a 2D array containing the number of tokens an arc connects between each place and token type
# places: an array of strings representing the different places in the system
# transitions: an array of strings representing the different transitions (events) in the system
# token_types: an array of strings representing the different types of tokens in the system

function create_tensor(arc_multiplicity, places, transitions, token_types)
   
    # The length of places is calculated and stored in num_places variable
    num_places = length(places)
    
    # The length of transitions is calculated and stored in num_transitions variable
    num_transitions = length(transitions)
    
    # The length of token_types is calculated and stored in num_token_types variable
    num_token_types = length(token_types)
    
    # A 3D tensor of zeros with dimensions num_places x num_transitions x num_token_types is created and stored in the tensor variable
    # Each element in this tensor initially has a value of 0
    tensor = zeros(Int, num_places, num_transitions, num_token_types)

    # Arc multiplicity values are assigned to the elements of the 3D tensor using three nested for-loops
    for i in 1:num_places, j in 1:num_transitions, k in 1:num_token_types
        
        # The arc_multiplicity value for the ith place and kth token type is assigned to the corresponding element in the 3D tensor
        # Here, we are accessing the ith row, jth column and kth depth of the tensor and assigning it the value arc_multiplicity[i, k]
        tensor[i, j, k] = arc_multiplicity[i, k]
    end

    # The final 3D tensor is returned
    return tensor
end


tensor = create_tensor(arc_multiplicity, places, transitions, token_types)

# Determine the available transitions based on token availability and arc multiplicity
function find_transition_index(transition, transitions)
    findfirst(x -> x == transition, transitions)
end

function check_token_counts(token_counts, tensor, places, token_types, transition,
                            transitions)
    for (i, place) in enumerate(places)
        for (k, token_type) in enumerate(token_types)
            j = find_transition_index(transition, transitions)
            if j != nothing && token_counts[place][token_type] < tensor[i, j, k]
                return false
            end
        end
    end
    return true
end

function get_available_transitions(token_counts, tensor, places, token_types, transitions)
    [transition
     for transition in transitions
     if check_token_counts(token_counts, tensor, places, token_types,
                           transition, transitions)]
end

available_transitions = get_available_transitions(token_counts, tensor, places, token_types,
                                                  transitions)

# Compute the effective arc multiplicity based on token availability
function compute_effective_multiplicity(token_counts, tensor, places, token_types,
                                        transitions)
    num_places = length(places)
    num_transitions = length(transitions)
    num_token_types = length(token_types)
    effective_multiplicity = zeros(Int, num_places, num_transitions, num_token_types)

    for i in 1:num_places, j in 1:num_transitions, k in 1:num_token_types
        effective_multiplicity[i, j, k] = min(token_counts[places[i]][token_types[k]],
                                              tensor[i, j, k])
    end

    return effective_multiplicity
end

effective_multiplicity = compute_effective_multiplicity(token_counts, tensor, places,
                                                        token_types, transitions)

# Randomly select the transitions to fire based on their probabilities and effective multiplicity
function select_transitions(available_transitions, effective_multiplicity)
    if isempty(available_transitions)
        return []
    end

    sample(available_transitions,
           weights(sum(effective_multiplicity[:, available_transitions,
                                              :], dims = 3)))
end

selected_transitions = select_transitions(available_transitions, effective_multiplicity)

# Update the token counts based on the selected transitions
function update_token_counts(token_counts, places, token_types, selected_transitions,
                             effective_multiplicity, transitions)
    for transition in selected_transitions
        for i in 1:num_places
            for k in 1:num_token_types
                token_counts[places[i]][token_types[k]] -= effective_multiplicity[i,
                                                                                  findfirst(x -> x ==
                                                                                                 transition,
                                                                                            transitions),
                                                                                  k]
            end
        end
    end
end

update_token_counts(token_counts, places, token_types, selected_transitions,
                    effective_multiplicity, transitions)

# Print the selected transitions, effective multiplicity, and updated token counts
println("Selected transitions: ", selected_transitions)
println("Effective multiplicity: ", effective_multiplicity)
println("Updated token counts: ", token_counts)










## ======== version 2 =================================
# Required Libraries
using Revise
using AlgebraicAgents
using ReactiveDynamics
using DifferentialEquations
using Distributions, Plots, DataFrames, Random
##

# Define an abstract transition
abstract type AbstractTransition end
# Define the structure of a cell
struct Cell
    cell_type::Symbol  # Normal or Cancer
    dynamical_state::Symbol  # Active or Inactive
end

# Define the structure of a place
struct Place
    id::String
    cells::Dict{Cell, Int}
end

# Define the structure for an input arc
struct InputArc
    id::String
    source::Place
    target::AbstractTransition
    token_type::Cell
    multiplicity::Int
end

# Define the structure for an output arc
struct OutputArc
    id::String
    source::AbstractTransition
    target::Place
    token_type::Cell
    multiplicity::Int
end


# Define the structure of a generalized Petri net
mutable struct GeneralizedPetriNet
    places::Vector{Place}
    transitions::Vector{AbstractTransition}
    marking::Dict{Place, Dict{Cell, Int}}
end


# Define the structure for a stochastic transition
mutable struct StochasticTransition
    id::String
    input_arcs::Vector{InputArc}
    output_arcs::Vector{OutputArc}
    rate_fn::Function
    function StochasticTransition(id::String, input_arcs::Vector{InputArc},
                                  output_arcs::Vector{OutputArc}, rate_fn::Function)
        function precondition(gpn::GeneralizedPetriNet)
            all(arc -> gpn.marking[arc.source][arc.token_type] >= arc.multiplicity,
                filter(arc -> arc.target.id == id, input_arcs))
        end
        function postcondition(gpn::GeneralizedPetriNet)
            begin
                for input_arc in input_arcs
                    gpn.marking[input_arc.source][input_arc.token_type] -= input_arc.multiplicity
                end
                for output_arc in output_arcs
                    gpn.marking[output_arc.target][output_arc.token_type] += output_arc.multiplicity
                end
            end
        end
        new{id, input_arcs, output_arcs, rate_fn}
    end
end

# Define a function to execute a transition
function execute_transition!(t::StochasticTransition, gpn::GeneralizedPetriNet)
    if t.precondition(gpn)
        t.postcondition(gpn)
    end
end

# Define a function to update the Petri net
function update_petri_net!(gpn::GeneralizedPetriNet)
    can_fire_transitions = filter(t -> t.precondition(gpn), gpn.transitions)
    if isempty(can_fire_transitions)
        return
    end
    # Order transitions based on their rates
    transition_rates = map(t -> t.rate_fn(gpn), can_fire_transitions)
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


function add_place!(gpn::GeneralizedPetriNet, place::Place)
    push!(gpn.places, place)
    gpn.marking[place] = place.cells
end

function add_transition!(gpn::GeneralizedPetriNet, transition::StochasticTransition)
    push!(gpn.transitions, transition)
end

function add_arc!(gpn::GeneralizedPetriNet, arc::Union{InputArc, OutputArc})
    transition = arc.source isa AbstractTransition ? arc.source : arc.target
    if arc isa InputArc
        push!(transition.input_arcs, arc)
    else
        push!(transition.output_arcs, arc)
    end
end




# Initialize an empty Generalized Petri Net
gpn = GeneralizedPetriNet([], [], Dict())

# Define cell types and dynamical states
Normal_Active = Cell(:Normal, :Active)
Normal_Inactive = Cell(:Normal, :Inactive)
Cancer_Active = Cell(:Cancer, :Active)
Cancer_Inactive = Cell(:Cancer, :Inactive)

# Define Places
place1 = Place("Place1", Dict(Normal_Active => 50))
place2 = Place("Place2", Dict(Normal_Inactive => 50))
place3 = Place("Place3", Dict(Cancer_Active => 50))
place4 = Place("Place4", Dict(Cancer_Inactive => 50))

# Add Places to the Generalized Petri Net
add_place!(gpn, place1)
add_place!(gpn, place2)
add_place!(gpn, place3)
add_place!(gpn, place4)

# Define rate function
rate_fn = _ -> 0.5

# Define Transitions
Transition1 = StochasticTransition("Transition1", [], [], rate_fn)
Transition2 = StochasticTransition("Transition2", [], [], rate_fn)

# Add Transitions to the Generalized Petri Net
add_transition!(gpn, Transition1)
add_transition!(gpn, Transition2)

# Define Input and Output Arcs
input_arc1 = InputArc("InputArc1", place1, Transition1, Normal_Active, 1)
output_arc1 = OutputArc("OutputArc1", Transition1, place2, Normal_Inactive, 1)
input_arc2 = InputArc("InputArc2", place3, Transition2, Cancer_Active, 1)
output_arc2 = OutputArc("OutputArc2", Transition2, place4, Cancer_Inactive, 1)

# Add Arcs to the Generalized Petri Net
add_arc!(gpn, input_arc1)
add_arc!(gpn, output_arc1)
add_arc!(gpn, input_arc2)
add_arc!(gpn, output_arc2)

# Update Transitions with their Input and Output Arcs
Transition1.input_arcs = [input_arc1]
Transition1.output_arcs = [output_arc1]
Transition2.input_arcs = [input_arc2]
Transition2.output_arcs = [output_arc2]

# Simulate the Generalized Petri Net
simulate_petri_net!(gpn, 100)


