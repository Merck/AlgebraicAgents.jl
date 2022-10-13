module AlgebraicAgents

using Glob
using UUIDs
using DataStructures
using MacroTools
using Crayons
using Requires

# abstract algebraic agent types
include("abstract.jl")
export AbstractAlgebraicAgent

# path-like structure of algebraic agents
include("paths.jl")
export @glob_str, @uuid_str # path wildcard, UUID obj constructor
export getagent, entangle!, disentangle!

# dynamic structure to store priority queue of algebraic interactions
# and and which contains a directory of algebraic integrators
include("opera.jl")
export AbstractOperaCall, AgentCall, Opera
## enqueue an action
export opera_enqueue!

# utility functions
include("utils.jl")
## convenient expr wraps
export @wrap
## declare derived sequence
export @derived
## convenient observable accessor, interaction schedulers
export @observables, @schedule, @schedule_call
## flat representation of agent hierarchy
export flatten
## instantiate an integration and add it to Julia's load path
export add_integration_to_path, @integration
## return a function which maps params to simulation results
export objective
## convenient algebraic wrap initialization
export @wrap
## extract wrap from complex types
export @get_agent

# interface: basic type definitions, interface (init, step, simulate, build_solution), accessors
include("interface.jl")
## basic type definitions
export FreeAgent
## general accessors
export getname, getuuid, getparent, inners
export getopera, getdirectory, getparameters, setparameters!
## observable accessors
export getobservable, gettimeobservable
## list of observables observed by an agent and exported by an agent, respectively
export ports_in, exposed_ports
## step!, simulate
export step!, simulate
# plot
export draw

# convenient algebraic agent subtyping
include("agent_macros.jl")
export @aagent

# algebraic agents' structure walking
include("walks.jl")
export prewalk, postwalk

# defines general sums and products of algebraic models
include("ops.jl")
export ⊕, @sum

function __init__()
    include(joinpath(@__DIR__, "integrations/loading.jl"))
    # DataFrame log out-of-the-box plots
    @require DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0" begin
        @require Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80" include("utils_plots.jl")
    end 
end

end