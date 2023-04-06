module AlgebraicAgents

using Requires

using Glob
using UUIDs
using MacroTools
using Crayons
using Random: randstring

# abstract algebraic agent types
include("abstract.jl")
export AbstractAlgebraicAgent

# path-like structure of algebraic agents
include("paths.jl")
export @glob_str, @uuid_str # path wildcard, UUID obj constructor
export getagent, by_name, entangle!, disentangle!

# dynamic structure to store priority queue of algebraic interactions
# and and which contains a directory of algebraic integrators
include("opera.jl")
export AgentCall, Opera
# Opera interface
export add_instantious!, poke, @call
export add_future!, @future
export add_control!, @control

# utility functions
include("utils.jl")
## convenient expr wraps
export @wrap
## declare derived sequence
export @derived
## convenient observable accessor, interaction schedulers
export @observables
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
## return type hierarchy suitable for Mermaid
export typetree_mmd, agent_hierarchy_mmd

# interface: basic type definitions, interface (init, step, simulate, build_solution), accessors
include("interface.jl")
## basic type definitions
export FreeAgent
## general accessors
export getname, getuuid, getparent, inners
export getopera, getdirectory, getparameters, setparameters!
## observable accessors
export getobservable, gettimeobservable
## list of observables exported by an agent
export observables
## step!, simulate, least projected time
export step!, simulate, projected_to
## plot
export draw

# convenient algebraic agent subtyping
include("agents.jl")
export @aagent
export setup_agent!

# algebraic agents' structure walking
include("walks.jl")
export prewalk, prewalk_ret, postwalk, postwalk_ret, topmost

# defines general sums and products of algebraic models
include("ops.jl")
export ⊕, @sum

# filter, transform queries in agent hierarchies
include("queries.jl")
export FilterQuery
export @f_str, @filter, filter
export TransformQuery
export @transform, transform

include("integrations/requires.jl")

end
