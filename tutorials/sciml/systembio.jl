# Systembio.jl is a Julia script that simulates a Petri net model of cellular dynamics. It uses the AlgebraicAgents and DifferentialEquations packages to model the behavior of different types of cells, including normal and cancer cells, and their interactions.

## 
using Revise
using AlgebraicAgents
using DifferentialEquations
using DataFrames

# Define the ODE function for cell dynamics
function cell_dynamics!(du, u, p, t)
    du[1] = -p[1] * u[1] # Example dynamics
end

abstract type AbstractCellType end
struct NormalCellA <: AbstractCellType end
struct NormalCellB <: AbstractCellType end
struct CancerCellA <: AbstractCellType end
struct CancerCellB <: AbstractCellType end

# Define the CellAgent with a DiffEqAgent field for dynamical_state
@aagent struct CellAgent
    id::Int
    cell_type::AbstractCellType
    dynamical_state_agent::DiffEqAgent
    time_in_active_state::Int
end
# CellAgent1 = CellAgent("1" , 1, NormalCellA(), diffeq_agent, 0)


mutable struct Place
    name::String
    tokens::Vector{CellAgent}
end


function map_state_to_value(state::Symbol)
    if state == :active
        return 1.0
    elseif state == :inactive
        return 0.5
    elseif state == :dormant
        return 0.0
    else
        error("Invalid state")
    end
end

# Function to create a DiffEqAgent
function create_diffeq_agent(id::Int,
        initial_state::Symbol,
        params::Vector{Float64},
        t_end::Float64)
    state_value = map_state_to_value(initial_state)  # Convert the symbolic state to a numerical value
    u0 = [state_value]
    tspan = (0.0, t_end) # Example time span
    prob = ODEProblem(cell_dynamics!, u0, tspan, params)
    return DiffEqAgent("$id", prob)
end


diffeq_agent = create_diffeq_agent(1, :inactive, [1.1], 20.0)

function create_cell_agent(id::Int, cell_type::AbstractCellType, initial_state::Symbol, params::Vector{Float64}, t_end::Float64)
    # create the DiffEqAgent with parames
    diffeq_agent = create_diffeq_agent(id, initial_state, params, t_end)
    # get the state value from the DiffEqAgent
    return CellAgent("$id", id, cell_type, diffeq_agent, 0)
end


# # function to simulate the DiffEqAgent at a given time with default params
# function simulate_agent(diffeq_agent::DiffEqAgent,
#         t_end::Float64,
#         params::Vector{Float64} = diffeq_agent.prob.p)
#     new_prob = remake(diffeq_agent, p = params, tspan = (0.0, t_end))
#     sol = solve(new_prob)
#     return sol(t_end)
# end

# cell_agent = create_cell_agent(1, NormalCellA(), :active, [0.1], 20.0)

# simulate_agent(cell_agent.dynamical_state_agent, 30.0)



struct Transition
    name::String
    input::Vector{Tuple{Int, Place, DataType}}
    output::Vector{Tuple{Int, Place, DataType}}
end



function add_token!(place::Place, token::CellAgent)
    push!(place.tokens, token)
end

function remove_token!(place::Place, token::CellAgent)
    deleteat!(place.tokens, findfirst(t -> t == token, place.tokens))
end




function simulate_dynamical_state!(cell_agent::CellAgent,
        cancer_cell_present::Bool,
        max_active_time::Int)
    # Access the state from the DiffEqAgent
    state = cell_agent.dynamical_state_agent.integrator.u[1]

    # Logic to update the dynamical state based on the presence of cancer cells
    if cancer_cell_present && state == :dormant || state == :inactive
        state = :active
        cell_agent.time_in_active_state = 0
    elseif state == :active
        cell_agent.time_in_active_state += 1
        if cell_agent.time_in_active_state >= max_active_time
            state = :dormant
            cell_agent.time_in_active_state = 0
        end
    end

    # Update the state in the DiffEqAgent
    cell_agent.dynamical_state_agent.integrator.u[1] = state
end


# ## Performing the Transition
# The function perform_transition! checks the feasibility of a transition by confirming if it has the required number of tokens in the input places. If the transition is feasible, it removes the tokens from the input places and adds new tokens to the output places. The function also updates the dynamical state of the tokens based on the presence of cancer cells.



# function perform_transition!(transition::Transition)
#     cancer_cell_exists = false
#     num_tokens = 0

#     for (count, place, token_type) in transition.input
#         tokens_to_remove = filter(t -> isa(t.cell_type, token_type), place.tokens)

#         if length(tokens_to_remove) < count
#             return false
#         end

#         for token in tokens_to_remove
#             if isa(token.cell_type, CancerCellA) || isa(token.cell_type, CancerCellB)
#                 cancer_cell_exists = true
#             end
#             num_tokens += 1
#         end
#     end

#     if cancer_cell_exists && num_tokens > 30
#         for (count, place, token_type) in transition.input
#             tokens_to_remove = filter(t -> isa(t.cell_type, token_type), place.tokens)
#             for token in tokens_to_remove[1:count]
#                 remove_token!(place, token)
#             end
#         end

#         for (count, place, token_type) in transition.output
#             for _ in 1:count
#                 new_cell_agent = create_cell_agent(rand(Int),
#                     token_type(),
#                     rand([:active, :inactive, :dormant]),
#                     [0.1])
#                 simulate_dynamical_state!(new_cell_agent,
#                     cancer_cell_exists,
#                     max_active_time)
#                 add_token!(place, new_cell_agent)
#             end
#         end

#         return true
#     end

#     return false
# end

function perform_transition!(transition::Transition,
        cancer_cell_exists::Bool,
        max_active_time::Int)
    for (count, place, token_type) in transition.output
        for _ in 1:count
            # Determine the initial state based on the model's rules
            initial_state = if cancer_cell_exists
                :active
            else
                rand([:active, :inactive, :dormant])
            end

            # Create a new CellAgent with the determined initial state
            new_cell_agent = create_cell_agent(
                # Generate a unique ID
                rand(Int),  # Generate a unique ID for the cell
                token_type(),  # The cell type
                initial_state,  # The initial state as a Symbol
                [0.1])

            # Simulate the dynamical state of the new cell agent
            simulate_dynamical_state!(new_cell_agent, cancer_cell_exists, max_active_time)

            # Add the new cell agent to the place
            add_token!(place, new_cell_agent)
        end
    end

    return true
end

# ## Defining the Petri Net
# We define a Petri Net using the previously defined Place and Transition structures. The Petri Net also includes InputArc and OutputArc structures that connect Places and Transitions.



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



# ## Simulation of the Petri Net
# We initialize the Petri Net with a certain number of cells and let the system evolve over a predefined number of time steps. At each time step, we update the dynamical state of each cell, check if each transition can fire, and if so, fire the transition. We also record the state of the system at each time step.



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
            cell_key = (typeof(cell.cell_type),
            # simulate(cell_agent.dynamical_state_agent).integrator.u)
                rand([:active, :inactive, :dormant]))
            cell_counts[cell_key] = get(cell_counts, cell_key, 0) + 1
        end
    end

    return cell_counts
end



# ## Visualization of the Petri Net Evolution
# the Plots package to visualize the evolution of the system. At each time step, we create a bar plot of the count of each type of cell in each dynamical state.


function plot_petri_net(pn::PetriNet)
    cell_counts = count_cells(pn)

    p = bar([string(key) for key in keys(cell_counts)],
        [value for value in values(cell_counts)],
        xlabel = "Cell Type and Dynamical State",
        ylabel = "Count",
        title = "Petri Net Simulation",
        legend = false)
    display(p)
end



# ## Running the Simulation
# To run the simulation, we initialize the Petri Net and then perform a series of updates in a loop. At each time step, we print out the current state of the Petri Net and generate a plot.



# ## Initializing the Petri Net

# We initialize the Petri net by creating the places (P1 and P2), the transitions (T1), and setting up the input and output arcs.

function init_petri_net(num_cells::Int, max_active_time::Int)
    # Define cell types
    cell_types = [NormalCellA, NormalCellB, CancerCellA, CancerCellB]
    # Define the places with CellAgents
    P1 = Place("P1",
        [create_cell_agent(
            i,
            rand(cell_types)(),
            rand([:active, :inactive, :dormant]),
            [0.1])
         for i in 1:round(Int, 0.5 * num_cells)])
    P2 = Place("P2",
        [create_cell_agent(
            i,
            rand(cell_types)(),
            rand([:active, :inactive, :dormant]),
            [0.1])
         for i in 1:round(Int, 0.5 * num_cells)])
    P3 = Place("P3", [])

    # Define the transitions
    T1 = Transition("T1", [(3, P1, NormalCellA), (1, P2, CancerCellA)],
        [(1, P3, CancerCellA)])

    # Define arcs
    input_arc1 = InputArc(P1, T1, NormalCellA, 30)
    input_arc2 = InputArc(P2, T1, CancerCellA, 30)
    output_arc1 = OutputArc(T1, P3, CancerCellA, 50)

    # Define the Petri net
    pn = PetriNet([P1, P2, P3], [T1], [input_arc1, input_arc2], [output_arc1])

    return pn
end





# ## Updating the Petri Net
# We update the Petri net by checking the state of the cells and performing transitions if possible.

function update_petri_net(pn::PetriNet)
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
            perform_transition!(transition, false, 2)
        end
    end
end





## Cell trajectory visulization
function plot_trajectory(cell_trajectory::Vector{Dict{Tuple{DataType, Symbol}, Int}})
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
    return p
end



function init_trajectory()
    # Initialize an empty array to store the states of the Petri net at each time step
    trajectory = Dict{Tuple{DataType, Symbol}, Int}[]

    return trajectory
end

function append_to_trajectory!(trajectory, pn)
    # Append the current state of the Petri net to the trajectory
    push!(trajectory, count_cells(pn))
end




##======== simulation ================
# Initialize Petri net
num_cells = 500
max_active_time = 5
pn = init_petri_net(num_cells, max_active_time)

# Define the time range
tspan = (0.0, 30.0)

# Initialize trajectory
traj = init_trajectory()

# Run the simulation
for t in tspan[1]:tspan[2]
    update_petri_net(pn)
    append_to_trajectory!(traj, pn)
end

# Visualize the trajectory
traj_plt = plot_trajectory(traj)
# save figure
savefig(traj_plt, joinpath(dirname(@__FILE__), "CellAutomata_heterogeneous_trajectory.png"))
