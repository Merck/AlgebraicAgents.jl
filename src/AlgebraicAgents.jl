module AlgebraicAgents

using Glob
using UUIDs
using DataStructures
using MacroTools
using Crayons
import Pkg

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
export add_integration
## return a function which maps params to simulation results
export objective

# interface: basic type definitions, interface (init, step, simulate, build_solution), accessors
include("interface.jl")
## basic type definitions
export FreeAgent
## general accessors
export getname, getuuid, getparent, inners
export getopera, getdirectory, getparameters, set_parameters!
## observable accessors
export getobservable, gettimeobservable
## list of observables observed by an agent and exported by an agent, respectively
export in_observables, out_observables
## step!, simulate
export step!, simulate
# plot
export draw

# convenient algebraic agent subtyping
include("agent_macros.jl")
export @oagent

# algebraic agents' structure walking
include("walks.jl")
export prewalk, postwalk

# defines general sums and products of algebraic models
include("operad.jl")
export ⊕, @sum

end