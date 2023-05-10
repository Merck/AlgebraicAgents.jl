"If `ex` is a macrocall, return the macro's name, else return `nothing`."
macroname(e) = Meta.isexpr(e, :macrocall) ? Symbol(strip(string(e.args[1]), '@')) : nothing

"Turn underscores into references of `x`, and wrap filter query as a function of `x`."
function interpolate_underscores(s, __module__ = AlgebraicAgents)::Expr
    ex = s isa AbstractString ? Meta.parse(s) : s
    sym = gensym()
    ex = MacroTools.prewalk(x -> x == :_ ? sym : x, ex)
    ex = Expr(:(->), sym, ex)

    Expr(:escape, Expr(:call, GlobalRef(Core, :eval), __module__, Expr(:quote, ex)))
end

"Supertype of queries."
abstract type AbstractQuery end

## filter queries
"""
    FilterQuery(query)
Simple property query; references agents via underscores `_`.

A query on an agent may result in an error; in that case, the agent will fail the filter condition by default.

See also [`@f_str`](@ref), [`filter`](@ref).

# Examples
```julia
filter(agents, f"_.age > 21 && _.name ∈ ['a', 'b']")
agents |> @filter _.age > 21 && _.name ∈ ['a', 'b']
```
"""
struct FilterQuery{T} <: AbstractQuery
    query::T
end

"""
    f"query"
Turn a query string into a query instance, see also [`FilterQuery`](@ref).

Supports string interpolations.

# Examples
```julia
filter(agents, f"_.age > 1 && _.name ∈ ['a', 'b']")
i = 1; filter(agents, f"_.age > \$i && _.name ∈ ['a', 'b']")
```
"""
macro f_str(query)
    :(FilterQuery($(interpolate_underscores(query))))
end

"""
    @filter query
Turn a filter query into a function of agents' hierarchy.
Accepts expressions (corresponding to q-strings) and query string.

See also [`FilterQuery`](@ref).
"""
macro filter(query)
    # if query is a raw expression (not a query string), transform explicitly
    query = if !Meta.isexpr(query, :macrocall) || Meta.isexpr(query, :string)
        :(FilterQuery($(interpolate_underscores(query))))
    else
        Expr(:escape, query)
    end

    quote
        query = $(query)
        a -> filter(a, query)
    end
end

"""
    filter(agent::AbstractAlgebraicAgent, queries...)
    filter(agents::Vector{<:AbstractAlgebraicAgent}, queries...)
Run filter query on agents in a hierarchy.

# Examples
```julia
filter(agent, f"_.age > 21 && _.name ∈ ['a', 'b']") # filter query
```
"""
function Base.filter(a::AbstractAlgebraicAgent, queries::Vararg{<:FilterQuery})
    filter(collect(values(flatten(a))), queries...)
end

function Base.filter(a::Vector{<:AbstractAlgebraicAgent},
                     queries::Vararg{<:FilterQuery})
    filtered = AbstractAlgebraicAgent[]
    for a in a
        all(q -> _filter(a, q), queries) && push!(filtered, a)
    end

    filtered
end

# low-level function to check an agent against filter query

"""
    _filter(agent, query)
Check if an agent satisfies filter condition.
"""
_filter(a::AbstractAlgebraicAgent, query::FilterQuery) =
    try
        query.query(a)
    catch
        false
    end

## transform queries
"""
    TransformQuery(name, query)
Simple transform query; references agents via underscores `_`.

See also [`@transform`](@ref).

# Examples
```julia
agent |> @transform(name=_.name)
agent |> @transform(name=_.name, _.age)
```
"""
struct TransformQuery{F <: Function} <: AbstractQuery
    name::Symbol
    query::F

    function TransformQuery(name::T,
                            query::F) where {T <: Union{Symbol, AbstractString},
                                             F <: Function}
        new{F}(Symbol(name), query)
    end
end

"""
    @transform queries...
Turn transform queries into an anonymous function of agents' hierarchy. See also [`TransformQuery`](@ref).

Accepts both anonymous queries (`_.name`) and named queries (`name=_.name`). By default, includes agent's uuid.
"""
macro transform(exs...)
    n_noname::Int = 0
    queries = map(ex -> Meta.isexpr(ex, :(=)) ? (ex.args[1], ex.args[2]) :
                        (n_noname += 1; ("query_$n_noname", ex)), exs)
    names, queries = map(x -> x[1], queries), map(x -> x[2], queries)
    quote
        queries = TransformQuery.($(names),
                                  [$(interpolate_underscores.(queries)...)])

        a -> transform(a, queries...)
    end
end

"""
    transform(agent::AbstractAlgebraicAgent, queries...)
    tranform(agent::Vector{<:AbstractAlgebraicAgent}, queries...)
Run transform query on agents in a hierarchy.

A query on an agent may result in an error; in that case, the respective agent's output is omitted for the result.

See also [`@transform`](@ref).

# Examples
```julia
agent |> @transform(name=_.name)
agent |> @transform(name=_.name, _.age)
```
"""
function transform(a::AbstractAlgebraicAgent, queries::Vararg{<:TransformQuery})
    transform(collect(values(flatten(a))), queries...)
end

function transform(a::Vector{<:AbstractAlgebraicAgent},
                   queries::Vararg{<:TransformQuery})
    results = []
    for a in a
        try
            r = (; uuid = getuuid(a), (Symbol(q.name) => q.query(a) for q in queries)...)
            push!(results, r)
        catch
        end
    end

    results
end
