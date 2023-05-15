using Revise
using DifferentialEquations, AlgebraicAgents
using Plots
using Random
Random.seed!(0)

abstract type AbstractCellType end

struct NormalCellA <: AbstractCellType end
struct NormalCellB <: AbstractCellType end
struct CancerCellA <: AbstractCellType end
struct CancerCellB <: AbstractCellType end

mutable struct Cell
    cell_type::AbstractCellType
    id::Int
    dynamical_state::Symbol
    time_in_active_state::Int
end

mutable struct Place
    name::String
    tokens::Vector{Cell}
end

struct Transition
    name::String
    input::Vector{Tuple{Int, Place, DataType}}
    output::Vector{Tuple{Int, Place, DataType}}
end

function add_token!(place::Place, token::Cell)
    push!(place.tokens, token)
end

function remove_token!(place::Place, token::Cell)
    deleteat!(place.tokens, findfirst(t -> t == token, place.tokens))
end

function simulate_dynamical_state!(cell::Cell, cancer_cell_present::Bool,
                                   max_active_time::Int)
    if cancer_cell_present &&
       (cell.dynamical_state == :dormant || cell.dynamical_state == :inactive)
        cell.dynamical_state = :active
        cell.time_in_active_state = 0
    elseif cell.dynamical_state == :active
        cell.time_in_active_state += 1
        if cell.time_in_active_state >= max_active_time
            cell.dynamical_state = :dormant
            cell.time_in_active_state = 0
        end
    end
end

function perform_transition!(transition::Transition)
    cancer_cell_exists = false
    num_tokens = 0

    for (count, place, token_type) in transition.input
        tokens_to_remove = filter(t -> isa(t.cell_type, token_type), place.tokens)

        if length(tokens_to_remove) < count
            return false
        end

        for token in tokens_to_remove
            if isa(token.cell_type, CancerCellA) || isa(token.cell_type, CancerCellB)
                cancer_cell_exists = true
            end
            num_tokens += 1
        end
    end

    if cancer_cell_exists && num_tokens > 30
        for (count, place, token_type) in transition.input
            tokens_to_remove = filter(t -> isa(t.cell_type, token_type), place.tokens)
            for token in tokens_to_remove[1:count]
                remove_token!(place, token)
            end
        end

        for (count, place, token_type) in transition.output
            for _ in 1:count
                new_cell = Cell(token_type(), rand(Int),
                                rand([:active, :inactive, :dormant]))
                simulate_dynamical_state!(new_cell)
                add_token!(place, new_cell)
            end
        end

        return true
    end

    return false
end

struct InputArc
    source::Place
    target::Transition
    cell_type::DataType
    weight::Int
end

struct OutputArc
    source::Transition
    target::Place
    cell_type::DataType
    weight::Int
end

struct PetriNet
    places::Vector{Place}
    transitions::Vector{Transition}
    input_arcs::Vector{InputArc}
    output_arcs::Vector{OutputArc}
end
max_active_time = 5
P1 = Place("P1",
           [Cell(NormalCellA(), i, rand([:active, :inactive, :dormant]), max_active_time)
            for i in 1:5])
P2 = Place("P2",
           [Cell(CancerCellA(), i, rand([:active, :inactive, :dormant]), max_active_time)
            for i in 1:2])
P3 = Place("P3", [])

T1 = Transition("T1", [(3, P1, NormalCellA), (1, P2, CancerCellA)], [(1, P3, CancerCellA)])

# if perform_transition!(T1)
#     println("Transition T1 fired successfully.")
# else
#     println("Transition T1 cannot fire.")
# end

# Define arcs
input_arc1 = InputArc(P1, T1, NormalCellA, 30)
input_arc2 = InputArc(P2, T1, CancerCellA, 30)
output_arc1 = OutputArc(T1, P3, CancerCellA, 50)

pn = PetriNet([P1, P2, P3], [T1], [input_arc1, input_arc2], [output_arc1])

## ============= ABM simulation =============
# Generate random initial conditions with 200 cells
Random.seed!(1234)
cell_types = [NormalCellA, NormalCellB, CancerCellA, CancerCellB]

function can_fire(transition::Transition, places::Vector{Place})
    for (count, place, token_type) in transition.input
        tokens_to_remove = filter(t -> isa(t.cell_type, token_type), place.tokens)

        if length(tokens_to_remove) < count
            return false
        end
    end

    return true
end

function count_cells(pn::PetriNet)
    cell_counts = Dict{Tuple{DataType, Symbol}, Int}()

    for place in pn.places
        for cell in place.tokens
            cell_key = (typeof(cell.cell_type), cell.dynamical_state)
            cell_counts[cell_key] = get(cell_counts, cell_key, 0) + 1
        end
    end

    return cell_counts
end

# Simulation parameters
num_time_steps = 1000

# Initialize the Petri net with the given number of cells
num_cells = 500
cell_types = [NormalCellA, NormalCellB, CancerCellA, CancerCellB]

P1 = Place("P1",
           [Cell(rand(cell_types)(), i, rand([:active, :inactive, :dormant]),
                 max_active_time)
            for i in 1:round(Int, 0.5 * num_cells)])
P2 = Place("P2",
           [Cell(rand(cell_types)(), i, rand([:active, :inactive, :dormant]),
                 max_active_time)
            for i in 1:round(Int, 0.5 * num_cells)])
# Initialize trajectory storage
cell_trajectory = []

# Set the maximum active time for a cell
max_active_time = 5  # Adjust this value according to your needs

# Run the simulation for all 500 cells
for t in 1:num_time_steps
    # Record the trajectory of each cell type and its associated dynamical_state
    push!(cell_trajectory, count_cells(pn))

    # Iterate through places
    for place in pn.places
        # Check if cancer cells are present in the place
        cancer_cell_present = any(cell -> isa(cell.cell_type, CancerCellA) ||
                                      isa(cell.cell_type, CancerCellB), place.tokens)

        # Update dynamical states of all cells in the place
        for cell in place.tokens
            simulate_dynamical_state!(cell, cancer_cell_present, max_active_time)
        end
    end

    # Iterate through transitions
    for transition in pn.transitions
        # Check if the transition can be fired
        if can_fire(transition, pn.places)
            # Fire the transition and update the system's state
            perform_transition!(transition)
        end
    end
end

## ============= Visualization =============
# Create an empty DataFrame
initial_cells_df = DataFrame(ID = Int[], CellType = String[], DynamicalState = Symbol[])

# Populate the DataFrame with the initial 500 cells
for place in [P1, P2]
    for cell in place.tokens
        cell_type = isa(cell.cell_type, NormalCellA) ? "NormalCellA" :
                    isa(cell.cell_type, NormalCellB) ? "NormalCellB" :
                    isa(cell.cell_type, CancerCellA) ? "CancerCellA" : "CancerCellB"

        push!(initial_cells_df, (cell.id, cell_type, cell.dynamical_state))
    end
end

# Display the DataFrame
initial_cells_df

# Initialize empty DataFrame
df_traj = DataFrame(cell_type = DataType[], dynamical_state = Symbol[], count = Int[],
                    time_step = Int[])

# Iterate over cell_trajectory
for (i, dict) in enumerate(cell_trajectory)
    for (key, value) in dict
        cell_type, dynamical_state = key
        push!(df_traj, (cell_type, dynamical_state, value, i))
    end
end

using Plots

# Convert cell type to string for plotting
df_traj[!, :cell_type] = string.(df_traj[!, :cell_type])

# Separate data frames based on cell type
df_normalA = filter(row -> row[:cell_type] == "NormalCellA", df_traj)
df_normalB = filter(row -> row[:cell_type] == "NormalCellB", df_traj)
df_cancerA = filter(row -> row[:cell_type] == "CancerCellA", df_traj)
df_cancerB = filter(row -> row[:cell_type] == "CancerCellB", df_traj)

# Initialize plot
p = plot()

# Add lines for each cell type and dynamical state
for df_cell in [df_normalA, df_normalB, df_cancerA, df_cancerB]
    for state in unique(df_cell[!, :dynamical_state])
        df_state = filter(row -> row[:dynamical_state] == state, df_cell)
        plot!(p, df_state[!, :time_step], df_state[!, :count],
              label = "$(df_state[1, :cell_type]) - $(state)")
    end
end

# Show plot
p
