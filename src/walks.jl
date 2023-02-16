# walking the agent hierarchy
# implements walk(f, agent)

"Applies `f` to each algebraic agent. Applies `f` to an agent before visiting its inners."
function prewalk(f, agent::T) where {T <: AbstractAlgebraicAgent}
    f(agent)
    foreach(a -> prewalk(f, a), values(inners(agent)))
end

"""
Applies `f` to each algebraic agent. Applies `f` to an agent before visiting its inners.
The results of each application of `f` are appended to a vector and returned.
"""
function prewalk_ret(f, agent::T) where {T <: AbstractAlgebraicAgent}
    ret = []
    append!(ret, [f(agent)])
    for a in values(inners(agent))
        append!(ret, prewalk_ret(f, a))
    end
    return ret
end

"Applies `f` to each algebraic agent. Applies `f` to an agent after visiting its inners."
function postwalk(f, agent::T) where {T <: AbstractAlgebraicAgent}
    foreach(a -> postwalk(f, a), values(inners(agent)))
    f(agent)
end

"""
Applies `f` to each algebraic agent. Applies `f` to an agent after visiting its inners.
The results of each application of `f` are appended to a vector and returned.
"""
function postwalk_ret(f, agent::T) where {T <: AbstractAlgebraicAgent}
    ret = []
    for a in values(inners(agent))
        append!(ret, postwalk_ret(f, a))
    end
    append!(ret, [f(agent)])
    return ret
end

"Applies `f` each algebraic agent in the agents tree and its relative path to `agent`."
relpath_walk(f, agent::T) where {T <: AbstractAlgebraicAgent} = _relpath_walk_up(f, agent, ".")

"Recursively move up, and for each parent agent, recursively visit all inner agents (except for `source`)."
function _relpath_walk_up(f, agent, path, source = nothing)
    f(agent, path)

    # move up
    if !isnothing(getparent(agent))
        _relpath_walk_up(f, getparent(agent), normpath(joinpath(path, "..")), agent)
    end

    # move down, ignore source branch
    _relpath_walk_down(f, agent, path, source)
end

"Recursively applies `f` to of the each algebraic agent's descendants."
function _relpath_walk_down(f, agent, path, source = nothing)
    for agent_ in values(inners(agent))
        path_ = normpath(joinpath(path, getname(agent_), "."))
        agent_ == source && continue # ignore source branch
        f(agent_, path_)

        # recursion
        _relpath_walk_down(f, agent_, path_)
    end
end

"Get top-most algebraic agent in a hierarchy."
topmost(a::T) where {T <: AbstractAlgebraicAgent} = isnothing(getparent(a)) ? a : topmost(getparent(a))
