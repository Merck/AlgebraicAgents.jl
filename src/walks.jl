# walking the agent hierarchy
# implements walk(f, agent)

"Applies `f` to each algebraic agent, returning the result. Applies `f` to an agent before visiting its inners."
function prewalk(f, agent::AbstractAlgebraicAgent)
    foreach(a -> prewalk(f, a), values(inners(agent)))

    f(agent)
end

"Applies `f` to each algebraic agent, returning the result. Applies `f` to an agent before visiting its inners."
function postwalk(f, agent)
    foreach(a -> postwalk(f, a), values(inners(agent)))

    f(agent)
end

"Applies `f` each algebraic agent in the agents tree and its relative path to `agent`."
relpath_walk(f, agent) = _relpath_walk_up(f, agent, ".")

"Recursively move up, and for each parent agent, recursively visit all inner agents (except for `source`)."
function _relpath_walk_up(f, agent, path, source=nothing)
    f(agent, path)

    # move up
    if !isnothing(getparent(agent))
        _relpath_walk_up(f, getparent(agent), normpath(joinpath(path, "..")), agent)
    end

    # move down, ignore source branch
    _relpath_walk_down(f, agent, path, source)
end

"Recursively applies `f` to of the each algebraic agent's descendants."
function _relpath_walk_down(f, agent, path, source=nothing)
    for agent_ in values(inners(agent))
        path_ = normpath(joinpath(path, getname(agent_), "."))
        agent_ == source && continue # ignore source branch
        f(agent_, path_)

        # recursion
        _relpath_walk_down(f, agent_, path_)
    end
end

"Get top-most algebraic agent in a hierarchy."
topmost(a::AbstractAlgebraicAgent) = isnothing(getparent(a)) ? a : topmost(getparent(a))