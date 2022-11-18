"If `ex` is a macrocall, return the macro's name, else return `nothing`."
macroname(e) = Meta.isexpr(e, :macrocall) ? Symbol(strip(string(e.args[1]), '@')) : nothing

"Interpret predecessor filter queries."
function interpolate_underscores_predecessor(s, __module__=AlgebraicAgents)::Expr
    ex = s isa AbstractString ? Meta.parse(s) : s
    sym = gensym()
    ex = MacroTools.prewalk(ex) do x
        if isexpr(x, :call) && (x.args[1] == :(≺))
            :($(x.args[3]) ∈ $(x.args[2]))
        else x end
    end
    ex = MacroTools.prewalk(x -> x == :_ ? :($sym.path) : x, ex)

    ex = Expr(:(->), sym, ex)
    
    Expr(:escape, Expr(:call, GlobalRef(Core, :eval), __module__, Expr(:quote, ex)))
end

"""
    p"query"
Turn a predecessor query string into a query instance, see also [`GeneralFilterQuery`](@ref).

Supports string interpolations.

# Examples
```julia
filter(agents, p\"""_ ≺ "parent" \""")
```
"""
macro p_str(query)
    :(GeneralFilterQuery($(interpolate_underscores_predecessor(query))))
end