# define abstract algebraic agent

"""
Abstract supertype of all algebraic agents.
This is a dynamic structure which parametrizes dynamics of the agent,
stores additional data required for the numerical simulation,
and optionally logs its state at selected timesteps.
"""
abstract type AbstractAlgebraicAgent end