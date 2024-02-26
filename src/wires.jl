"""
    get_wires_to(a)
Get wires going into an agent.
"""
function get_wires_to(a::AbstractAlgebraicAgent)
    return filter(w -> w.to == a, getopera(a).wires)
end

"""
    get_wires_from(a)
Get wires originating from an agent.
"""
function get_wires_from(a::AbstractAlgebraicAgent)
    return filter(w -> w.from == a, getopera(a).wires)
end

"""
    retrieve_input_vars(a)
Return a dictionary with values along wires going into `a`,
specificed as `target => value` pairs.

```julia
retrieve_input_vars(alice) # Dict("alice1_x" => "alice")
```
"""
function retrieve_input_vars(a::AbstractAlgebraicAgent)
    wires = filter(w -> (w.to == a) && !isnothing(w.from_var_name), getopera(a).wires)

    observables = map(wires) do w
        w.to_var_name => getobservable(w.from, w.from_var_name)
    end

    return Dict(observables...)
end

# If `a` is a string or an UUID, retrieve the agent.
function to_agent(a, relative)
    if !isa(relative, AbstractAlgebraicAgent)
        return getagent(a, relative)
    else
        return relative
    end
end

"""
    add_wire!(a; from, to, from_var_name, to_var_name)
Add a wire connecting two agents.

# Examples
```julia
add_wire!(joint_system; from=alice, to=bob, from_var_name="alice_x", to_var_name="bob_x")
```
"""
function add_wire!(a::AbstractAlgebraicAgent;
        from::T,
        to::T,
        from_var_name = nothing,
        to_var_name = nothing) where {T <: Union{AbstractAlgebraicAgent, AbstractString, UUID}}
    from, to = to_agent(a, from), to_agent(a, to)
    from_var_name = something(from_var_name, to_var_name)
    to_var_name = something(to_var_name, from_var_name)

    wire = (; from, from_var_name = from_var_name, to, to_var_name = to_var_name)

    return add_wire!(a, wire)
end

add_wire!(a::AbstractAlgebraicAgent, w::Wire) = push!(getopera(a).wires, w)

"""
    delete_wires!(a; from, to, from_var_name, to_var_name)
Delete wires connecting two agents. Optionally, specify source and target variables.

# Examples
```julia
delete_wires!(joint_system; from=alice, to=bob)
delete_wires!(joint_system; from=alice, to=bob, from_var_name="alice_x", to_var_name="bob_x")
```
"""
function delete_wires!(a::AbstractAlgebraicAgent;
        from::T,
        to::T,
        from_var_name = nothing,
        to_var_name = nothing) where {T <: Union{AbstractAlgebraicAgent, AbstractString, UUID}}
    from, to = to_agent(a, from), to_agent(a, to)

    ixs = findall(x -> x.from == from && x.to == to, getopera(a).wires)

    if !isnothing(from_var_name)
        ixs = ixs ∩ findall(x -> x.from_var_name == from_var_name, getopera(a).wires)
    end

    if !isnothing(to_var_name)
        ixs = ixs ∩ findall(x -> x.to_var_name == to_var_name, getopera(a).wires)
    end

    foreach(ix -> deleteat!(getopera(a).wires, ix), ixs)

    return getopera(a).wires
end

"""
    wiring_diagram(agent; parentship_edges=true, wires=true)
    wiring_diagram(agents; parentship_edges=true, wires=true)
    wiring_diagram(groups; group_labels=nothing, parentship_edges=true, wires=true)

Render a Graphviz graph of agents in an hierarchy.
By default, the graph shows edges between parent and child agents,
and annotated wires.

Also see [`agent_hierarchy_mmd`](@ref).

# Examples
```julia
# Build a compound problem.
joint_system = ⊕(alice, bob, name = "joint system")

wiring_diagram(joint_system)

# Do not show edges between parents and children.
wiring_diagram(joint_system; parentship_edges=false)

# Only show listed agents.
wiring_diagram([alice, alice1, bob, bob1])

# Group agents into two clusters.
wiring_diagram([[alice, alice1], [bob, bob1]])
# Provide labels for clusters.
wiring_diagram([[alice, alice1], [bob, bob1]]; group_labels=["alice", "bob"], parentship_edges=false)
```
"""
function wiring_diagram end

function wiring_diagram(agent::AbstractAlgebraicAgent; kwargs...)
    all_agents = collect(values(getdirectory(agent)))

    return wiring_diagram(all_agents; kwargs...)
end

function wiring_diagram(agents::Vector{T};
        parentship_edges = true,
        wires = true) where {T <: AbstractAlgebraicAgent}
    wiring_diagram([agents]; parentship_edges, wires)
end

function wiring_diagram(groups;
        group_labels = nothing,
        parentship_edges = true,
        wires = true)
    nodes = build_nodes(groups; group_labels)
    edges_parentship, edges_wires = build_edges(vcat(groups...))

    edges = ""
    if parentship_edges
        edges *= "\n" * edges_parentship
    end

    if wires
        edges *= "\n" * edges_wires
    end

    return """
    digraph "algagents" {
        compound=true;
        node[color=Teal, fontsize=7.0, width=0.5, height=0.5, shape=circle];
        $nodes
        $edges
    }"""
end

# Build code for nodes or subgraphs, in case multiple groups are specified.
function build_nodes(groups; group_labels = nothing)
    if length(groups) == 1
        nodes = ["""$i [label="$(getname(a))"]""" for (i, a) in enumerate(only(groups))]

        return join(nodes, "\n")
    else
        subgraphs = []
        j = 0
        for (i_group, group) in enumerate(groups)
            nodes = ["""$(j+i) [label="$(getname(a))"]""" for (i, a) in enumerate(group)]

            push!(subgraphs,
                """
                subgraph cluster_$i_group {\n
                """ *
                (!isnothing(group_labels) ? """label="$(group_labels[i_group])" \n""" :
                 "") *
                join(nodes, "\n") *
                "\n}")
            j += length(group)
        end

        return join(subgraphs, "\n")
    end
end

# Build parentship edges and wires.
function build_edges(all_agents)
    parents = map(all_agents) do a
        parent = getparent(a)
        while !isnothing(parent) && !in(parent, all_agents)
            parent = getparent(parent)
        end

        parent
    end

    edges_parentship = []
    for (i, a) in enumerate(all_agents)
        if !isnothing(parents[i])
            p = parents[i]
            ix1, ix2 = findfirst(==(p), all_agents), findfirst(==(a), all_agents)
            push!(edges_parentship,
                "$ix1 -> $ix2 [len=1, penwidth=0.5, arrowsize=0.4, arrowtype=normal, style=dashed, fontsize=5.0, color=grey]")
        end
    end

    edges_wires = []
    for a in all_agents, b in all_agents
        ix1, ix2 = findfirst(==(a), all_agents), findfirst(==(b), all_agents)

        oriented_wires_between = get_wires_from(a) ∩ get_wires_to(b)
        for wire in oriented_wires_between
            push!(edges_wires,
                "$ix1 -> $ix2 [len=1, headlabel=$(wire.from_var_name), taillabel=$(wire.to_var_name), arrowsize=0.3, arrow=normal, fontsize=7.0]")
        end
    end

    return join(edges_parentship, "\n"), join(edges_wires, "\n")
end
