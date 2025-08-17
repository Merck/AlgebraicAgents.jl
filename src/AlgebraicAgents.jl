module AlgebraicAgents

using Requires

using Glob
using UUIDs
using MacroTools
using Crayons
using Random: randstring

# abstract agent types
include("abstract.jl")
export AbstractAlgebraicAgent, AbstractConcept

# path-like structure of agents
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

## declare derived sequence
export @derived
## flat representation of agent hierarchy
export flatten_hierarchy
## instantiate an integration and add it to Julia's load path
export add_integration_to_path, @integration
## return a function which maps params to simulation results
export objective
## wrap a dynamical system as an agent, extract agent as the system's property
export wrap_system, extract_agent
## return type hierarchy suitable for Mermaid
export typetree_mmd, agent_hierarchy_mmd

# interface: basic type definitions, interface (init, step, simulate, build_solution), accessors
include("interface.jl")
## basic type definitions
export FreeAgent
## general accessors
export getname, getuuid, getparent, inners
export getopera, getdirectory, getparameters, setparameters!
## observables interface
export observables, getobservable, gettimeobservable
## step!, simulate, least projected time
export step!, simulate, projected_to
## plot
export draw
## save and load
export save, load

# Annotate and display the "input" and "output" of each agent in a hierarchy,
# similar to how "wires" connect the agents.
include("wires.jl")
export get_wires_from, get_wires_to
export add_wire!, delete_wires!
export retrieve_input_vars
export wiring_diagram

# concepts and relations
include("relations.jl")
export Concept, add_concept!, add_relation!, remove_concept!, remove_relation!
export get_relations, isrelated, concept_graph, get_relation_closure

# convenient agent subtyping
include("agents.jl")
export @aagent
export setup_agent!

# agents' structure walking
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

# Graphviz rendering
include("graphviz.jl")
export run_graphviz

include("requires.jl")

end
