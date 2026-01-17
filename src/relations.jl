## concepts and relations

common_fields_concept = (:uuid, :name, :properties, :opera)

mutable struct Concept <: AbstractConcept
    uuid::UUID
    name::AbstractString

    properties::AbstractDict

    opera::Union{Opera, Nothing}

    @doc """
        Concept(name, properties)
    Create a new concept with the given `name` and `properties`.
    Use [`add_concept!`](@ref) to attach the concept to a hierarchy of agents.    
    """
    function Concept(name::AbstractString, properties::AbstractDict)
        m = new()
        m.uuid = uuid4()
        m.name = name
        m.properties = properties
        m.opera = nothing

        return m
    end
end

"""
    getname(c::AbstractConcept)
Get the name of a concept.
"""
getname(c::AbstractConcept) = c.name

"""
    getuuid(c::AbstractConcept)
Get the UUID of a concept.
"""
getuuid(c::AbstractConcept) = c.uuid

"""
    add_concept!(system::Union{AbstractAlgebraicAgent, Opera}, concept::Concept)
Add a `concept` to the system, which is either an agent or an `Opera` instance.
"""
function add_concept!(system::Union{AbstractAlgebraicAgent, Opera}, concept::Concept)
    opera = system isa Opera ? system : getopera(system)
    concept.opera = opera

    push!(opera.concepts, concept)
end

"""
    remove_concept!(system::Union{AbstractAlgebraicAgent, Opera}, concept::Concept)
Remove a `concept` from the system, which is either an agent or an `Opera` instance.
"""
function remove_concept!(system::Union{AbstractAlgebraicAgent, Opera}, concept::Concept)
    opera = system isa Opera ? system : getopera(system)

    # Remove relations involving the concept.
    filter!(
        x -> getuuid(x.from) != getuuid(concept) &&
             getuuid(x.to) != getuuid(concept), opera.relations)
    # Remove concept.
    deleteat!(opera.concepts, findfirst(x -> getuuid(x) == getuuid(concept), opera.concepts))

    concept.opera = nothing

    return concept
end

"""
    add_relation!(from, to, relation::Symbol)
Add a relation between two concepts or agents.

The `from` argument is the entity from which the relation originates,
and the `to` argument is the entity to which the relation points.
"""
function add_relation!(from, to, relation::Symbol)
    if !isa(relation, Symbol)
        @error "Relation must be a Symbol, got $(typeof(relation))"
    end

    if from isa RelatableType && to isa RelatableType
        new_relation = ConceptRelation(from, to, relation)
    else
        @error "Invalid types for `from` and `to`: $(typeof(from)), $(typeof(to))"
    end

    if isnothing(from.opera) || isnothing(to.opera) || (from.opera != to.opera)
        @error "Cannot add relation between concepts or agents in different operas."
    end

    opera = something(from.opera, to.opera)
    from.opera = to.opera = opera

    push!(opera.relations, new_relation)

    return new_relation
end

"""
    remove_relation!(from, to, relation = nothing)
Remove a relation between two concepts or agents.

See [`add_relation!`](@ref) for details on how to add relations.
"""
function remove_relation!(from, to, relation = nothing)
    opera = something(from.opera, to.opera)

    if opera === nothing
        @error "Cannot remove relation: concepts or agents are not part of any opera."
    end

    if isnothing(relation)
        # Remove all relations between from and to
        filter!(
            x -> !(x.from == from && x.to == to) &&
                 !(x.from == to && x.to == from), opera.relations)
    else
        # Remove specific relation
        filter!(x -> !(x.from == from && x.to == to && x.relation == relation),
            opera.relations)
    end

    return opera.relations
end

"""
    get_relations(entity, relation = nothing)
Get entities related to the given concept or agent.
If `relation` is provided, only entities related by that relation are returned.
"""
function get_relations(entity::RelatableType, relation = nothing)
    opera = getopera(entity)
    if isnothing(opera)
        return []
    end

    if isnothing(relation)
        return filter(x -> x.from == entity || x.to == entity,
            opera.relations)
    else
        return filter(
            x -> (x.from == entity || x.to == entity) &&
                 x.relation == relation, opera.relations)
    end
end

"""
    isrelated(from::RelatableType, to::RelatableType, relation = nothing)
Check if there is a relation between two concepts or agents.
If `relation` is provided, check for that specific relation.
"""
function isrelated(from::RelatableType, to::RelatableType, relation = nothing)
    isnothing(getopera(from)) && return false

    if isnothing(relation)
        return any(r -> r.from == from && r.to == to, getopera(from).relations)
    else
        return any(r -> r.from == from && r.to == to && r.relation == relation, getopera(from).relations)
    end
end

"""
    get_related_entities(entity::RelatableType, relation = nothing)
Get all entities related to the given `entity` by a specific `relation`.
If `relation` is not provided, all related entities are returned.
"""
function get_related_entities(entity::RelatableType, relation = nothing)
    all_relations = isnothing(relation) ? get_relations(entity) :
                    get_relations(entity, relation)

    related_entities = Set{RelatableType}()
    for r in all_relations
        if r.from == entity
            push!(related_entities, r.to)
        else
            push!(related_entities, r.from)
        end
    end

    return collect(related_entities)
end

# Pretty-printing Concepts

"""
    print_concept(io::IO, ::MIME"text/plain", c::AbstractConcept)
    print_concept(io::IO, c::AbstractConcept)
Pretty-print a Concept, showing its name, UUID, type, and all related agents or concepts with relation labels.
"""

function print_concept(io::IO, ::MIME"text/plain", c::AbstractConcept)
    indent = get(io, :indent, 0)

    # Header line
    print(io, "^"^indent, "concept ", crayon"bold cyan", getname(c), crayon"reset",
        " with uuid ", crayon"cyan", string(getuuid(c))[1:8], crayon"reset",
        " of type ", crayon"cyan", typeof(c), crayon"reset")

    # List all related entities
    for rel in get_relations(c)
        # Determine the other end of the relation
        if rel.from == c
            other = rel.to
            arrow = "→"
        else
            other = rel.from
            arrow = "←"
        end

        # Format the related object name and type
        if other isa AbstractConcept
            name_str = getname(other)
            type_label = "[concept]"
        else
            name_str = getname(other)
            type_label = "[agent]"
        end

        # Print relation line
        print(io, "\n", " "^(indent+2), arrow, " ", name_str, " ", crayon"magenta",
            Symbol(rel.relation), crayon"reset", " ", type_label)
    end
end

function print_concept(io::IO, c::AbstractConcept)
    indent = get(io, :indent, 0)
    related_entities = join([getname(o.from == c ? o.to : o.from) for o in get_relations(c)], ", ")

    print(io,
        " "^indent *
        "$(typeof(c)){name=$(getname(c)), uuid=$(string(getuuid(c))[1:8]), related_entities=$(related_entities)}")
end

# Override Base.show for Concepts

Base.show(io::IO, m::MIME"text/plain", c::AbstractConcept) = print_concept(io, m, c)
Base.show(io::IO, c::AbstractConcept) = print_concept(io, c)

# Pretty-printing Relations

"""
    print_relation(io::IO, ::MIME"text/plain", r::ConceptRelation)
    print_relation(io::IO, r::ConceptRelation)
Pretty-print a ConceptRelation, showing the relation type and the names of the related concepts or agents.
"""
function print_relation(io::IO, ::MIME"text/plain", r::ConceptRelation)
    indent = get(io, :indent, 0)
    from_name = getname(r.from)
    from_type = r.from isa AbstractConcept ? "concept" : "agent"
    to_type = r.to isa AbstractConcept ? "concept" : "agent"
    to_name = getname(r.to)
    relation_symbol = string(r.relation)
    print(io, "^"^indent, "relation ", crayon"bold cyan",
        from_name, crayon"reset", " [$from_type] ",
        crayon"magenta", relation_symbol, crayon"reset", " ", crayon"bold cyan",
        to_name, crayon"reset", " [$to_type]")
end

function print_relation(io::IO, r::ConceptRelation)
    indent = get(io, :indent, 0)
    from_name = getname(r.from)
    to_name = getname(r.to)

    print(io,
        " "^indent *
        "$(typeof(r)){from=$(from_name), relation=$(r.relation), to=$(to_name)}")
end

# Override Base.show for ConceptRelation
Base.show(io::IO, m::MIME"text/plain", r::ConceptRelation) = print_relation(io, m, r)
Base.show(io::IO, r::ConceptRelation) = print_relation(io, r)

# Graphviz representation of concepts and relations

"""
    concept_graph(entity)
    concept_graph(entities)

Build a Graphviz `digraph` representation of all concepts and agents in the shared Opera.
If a single `entity` is provided, then all concepts and agents in the hierarchy are included.
If multiple `ents` are provided, only relations between them are included.

- Concepts are drawn as boxes, agents as ellipses.
- Directed edges carry the relation symbol as their label.

# Examples
```julia
# given two entangled agents and some concepts:
alice, bob = MyAgent("alice"), MyAgent("bob")
entangle!(alice, bob)

c_apple  = Concept("Apple",  Dict())
c_fruit  = Concept("Fruit",  Dict())
add_concept!(alice, c_apple)
add_concept!(alice, c_fruit)
add_relation!(c_apple, c_fruit, :is_a)
add_relation!(alice, c_apple, :owns)

println(concept_graph([alice, bob], name="demo"))
```
"""
function concept_graph(entity::RelatableType)
    all_entities = union(collect(values(getopera(entity).directory)), getopera(entity).concepts)
    return concept_graph(RelatableType[all_entities...])
end

"""
    get_relation_closure(entity::RelatableType)
    get_relation_closure(entities::Vector{RelatableType})
Get the closure of relations for a vector of entities.
"""
function get_relation_closure(entity::RelatableType)
    # For a single entity, find all related entities, until no new entities are found.
    return get_relation_closure(RelatableType[entity])
end

function get_relation_closure(entities::Vector{RelatableType})
    # For each entity, add all related entities, until no new entities are found.
    closure = Set(entities)
    changed = true
    while changed
        changed = false
        for e in closure
            related = get_relations(e)
            for r in related
                if r.from in closure && r.to in closure
                    continue  # Both ends already in closure
                end
                new_entity = r.from == e ? r.to : r.from
                if !(new_entity in closure)
                    push!(closure, new_entity)
                    changed = true
                end
            end
        end
    end

    return collect(closure)
end

function concept_graph(entities::Vector{RelatableType})
    # Assume all agents share one Opera
    opera = getopera(entities[1])
    # Concepts, agents, and relations
    concepts = filter(x -> x isa AbstractConcept, entities)
    agents = filter(x -> x isa AbstractAlgebraicAgent, entities)
    relations = filter(x -> x.from in entities && x.to in entities, opera.relations)

    io = IOBuffer()
    print(io, """
        digraph \"algagents_relations\" {
            rankdir=LR;
            node [fontsize=10];
        """)

    # Emit concept nodes
    for c in concepts
        id = string(getuuid(c))[1:8]
        label = replace(c.name, '"' => "\\\"")# make transparent stroke
        println(io,
            "  \"$id\" [label=\"$label\", shape=circle, style=filled, fontsize=7.0, width=0.5, height=0.5, fillcolor=lightblue, color=\"transparent\"];")
    end

    # Emit agent nodes (if Opera stores them)
    for a in agents
        id = string(getuuid(a))[1:8]
        name = replace(getname(a), '"' => "\\\"")
        println(io,
            "  \"$id\" [label=\"$name\", color=Teal, fontsize=7.0, width=0.5, height=0.5, shape=circle];")
    end

    # Emit edges for all relations
    for rel in relations
        src = rel.from
        dst = rel.to
        src_id = isa(src, AbstractConcept) ? string(getuuid(src))[1:8] :
                 string(getuuid(src))[1:8]
        dst_id = isa(dst, AbstractConcept) ? string(getuuid(dst))[1:8] :
                 string(getuuid(dst))[1:8]
        lbl = string(rel.relation)
        println(io,
            "  \"$src_id\" -> \"$dst_id\" [label=\"$lbl\", fontsize=5, penwidth=0.5, arrowsize=0.4];")
    end

    println(io, "}")
    return String(take!(io))
end
