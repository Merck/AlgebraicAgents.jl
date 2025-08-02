# define abstract algebraic agent

"""
    AbstractAlgebraicAgent
Abstract supertype of all algebraic agents.
This is a dynamic structure which parametrizes dynamics of the agent,
stores additional data required for the numerical simulation, 
and optionally logs its state at selected timesteps.
"""
abstract type AbstractAlgebraicAgent end

"""
    AbstractConcept
This is an abstract type for concepts in the algebraic agents framework.
It is used to define the structure of concepts that can be used to attach additional properties or behaviors to agents.
"""
abstract type AbstractConcept end

const RelatableType = Union{AbstractConcept, AbstractAlgebraicAgent}