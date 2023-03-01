"Returns a glob string to enable wildcard matching of algebraic agents paths."
macro glob_str(pattern, flags...)
    if "s" ∈ flags
        pattern *= "/"
        flags = setdiff!(collect(flags), ("s",))
    end

    Glob.FilenameMatch(pattern, flags...)
end

"Returns UUID object given a uuid string."
macro uuid_str(uuid)
    :(UUID($uuid))
end

"Retrieve an algebraic agent at `path`, relatively to `agent`."
function getagent(::AbstractAlgebraicAgent, ::Any) end

"""
    getagent(a::AbstractAlgebraicAgent, uuid::UUID)
Get an algebraic agent given its uuid.

## Examples
```julia
getagent(a, UUID("2a634aad-0fbe-4a91-a605-bfbef4d57f95"))
getagent(a, uuid"2a634aad-0fbe-4a91-a605-bfbef4d57f95")
```
"""
function getagent(a::AbstractAlgebraicAgent, uuid::UUID)
    if haskey(getdirectory(a), uuid)
        getdirectory(a)[uuid]
    else
        @error "algebraic agent with uuid $uuid not found!"
    end
end

"""
    getagent(agent::AbstractAlgebraicAgent, path::AbstractString)
Get an algebraic agent given its relative path.

## Examples
```julia
getagent(a, "../agent")
```
"""
function getagent(agent::AbstractAlgebraicAgent, path::AbstractString)
    # absolute path, resolve from the root
    isabspath(path) && return getagent(topmost(agent), path)

    path = normpath(joinpath(path, "."))
    if haskey(relpathrefs(agent), path)
        # lookup in the relpathrefs
        getagent(agent, relpathrefs(agent)[path])
    else
        agent_ = agent
        for p in splitpath(path)
            if p == ".."
                agent_ = getparent(agent_)
            elseif p ∉ [".", "/"]
                agent_ = inners(agent_)[p]
            end
        end
        # memoize relative path
        push!(relpathrefs(agent), path => getuuid(agent_))

        agent_
    end
end

"""
    getagent(agent::AbstractAlgebraicAgent, path::Union{Glob.FilenameMatch, Regex})
Get an algebraic agent given a regex or glob string.

## Examples
```julia
getagent(a, r"agent.*")
getagent(a, glob"**/agent/")
```
"""
function getagent(agent::AbstractAlgebraicAgent, path::Union{Glob.FilenameMatch, Regex})
    # get relpathrefs
    get_relpathrefs!(agent)
    # walk the relpathrefs, filter algebraic agent's paths
    refs = UUID[]
    foreach(relpathrefs(agent)) do relpathref
        if occursin(path, relpathref[1])
            push!(refs, relpathref[2])
        end
    end

    # project uuids
    getagent.(Ref(agent), refs)
end

"With respect to `agent`, memoize relative relpath references of agents in the hiearchy."
function get_relpathrefs!(agent::AbstractAlgebraicAgent)
    relpath_walk(agent) do agent_, path
        push!(relpathrefs(agent), path => getuuid(agent_))
    end

    relpathrefs(agent)
end

# insert, remove agent
"
    entangle!(parent, agent)
Push an agent to the hierachy.

# Examples
```julia
entagle!(parent, ancestor)
```
"
function entangle!(parent::AbstractAlgebraicAgent, agent::AbstractAlgebraicAgent)
    setparent!(agent, parent)
    push!(inners(parent), getname(agent) => agent)
    merge!(getdirectory(parent), getdirectory(agent))

    # sync directories and operas
    prewalk(agent -> sync_opera!(agent, getopera(parent)), agent)

    agent
end

"
    disentangle!(agent)
Detach an agent from its parent.
Optionally set `remove_relpathrefs=false` keyword to skip removing the relative pathrefs.

# Examples
```julia
disentangle!(agent)
```
"
function disentangle!(agent::AbstractAlgebraicAgent; remove_relpathrefs = true)
    isnothing(getparent(agent)) && return agent

    opera_inners = Opera()
    # copy interactions
    foreach(setdiff(fieldnames(Opera), (:directory,))) do f
        setproperty!(opera_inners, f, getproperty(getopera(agent), f) |> deepcopy)
    end

    inners_uuid = UUID[]
    prewalk(agent) do a
        push!(inners_uuid, getuuid(a))
        push!(opera_inners.directory, getuuid(a) => a)
    end

    # sync operas for hierarchy under agent
    prewalk(agent) do agent_
        sync_opera!(agent_, opera_inners)
    end

    remove_relpathrefs && prewalk(topmost(agent)) do agent_
        if getuuid(agent_) ∈ inners_uuid
            rpr = relpathrefs(agent_)
            for (k, v) in rpr
                v ∉ inners_uuid && pop!(rpr, k)
            end
        else
            rpr = relpathrefs(agent_)
            for (k, v) in rpr
                v ∈ inners_uuid && pop!(rpr, k)
            end
        end
    end

    directory_parent = getdirectory(getparent(agent))
    for k in keys(directory_parent)
        k ∈ inners_uuid && pop!(directory_parent, k)
    end

    setparent!(agent, nothing) # detach for external structure (parent agent)

    agent
end

"Construct a hierarchy of algebraic agents from a dictionary of `path => agent` pairs."
function construct(hierarchy::Dict{String, AbstractAlgebraicAgent})
    agents = []
    for (path, agent) in hierarchy
        path = normpath(joinpath(path, "."))
        index = length(splitpath(path))
        push!(agents, (index, path, agent))
    end

    sort!(agents, by = a -> a[1])

    top = popfirst!(agents)
    @assert top[2] == "."
    top = top[3]
    for (_, path, agent) in agents
        entangle!(getagent(top, dirname(path)), agent)
    end

    top
end

"""
    by_name(agent, name::AbstractString; inners_only=false)
Return agents in the hierachy with the given `name`.
If `inners_only==true`, consider descendants of `agent` only.
"""
function by_name(agent::AbstractAlgebraicAgent, name::AbstractString; inners_only = false)
    agent = inners_only ? agent : topmost(agent)
    agents = []
    prewalk(a -> (getname(a) == name) && push!(agents, a), agent)

    agents
end

"""
    by_name(agent, name::Union{Glob.FilenameMatch, Regex})
Return agents in the hierarchy whose names match the given wildcard.
If `inners_only==true`, consider descendants of `agent` only.
"""
function by_name(agent::AbstractAlgebraicAgent, name::Union{Glob.FilenameMatch, Regex};
                 inners_only = false)
    agent = inners_only ? agent : topmost(agent)
    agents = []
    prewalk(a -> (occursin(name, getname(a))) && push!(agents, a), agent)

    agents
end
