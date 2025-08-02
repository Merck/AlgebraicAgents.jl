## Graphviz rendering

# see https://github.com/AlgebraicJulia/Catlab.jl/blob/8d35ef724f0f0864ecdccef173eec958329f43e5/src/graphics/Graphviz.jl

gv_backend(backend::Symbol, prog) = gv_backend(Val{backend}, prog)
gv_backend(::Type{<:Val}, prog) = prog

"""
    run_graphviz(io::IO, graph::AbstractString; prog::Symbol=:dot, format::String="svg")
    run_graphviz(path::AbstractString, graph::AbstractString; prog::Symbol=:dot, format::String="svg")
Run the Graphviz program to render the graph and stream the results into `io`. 

This requires either `prog` (e.g., `dot`) to be available in your path (see https://graphviz.org)
or for the `Graphviz_jll` package to be installed and loaded before calling this function.

See [`wiring_diagram`](@ref) to obtain the Graphviz wiring diagram for an agent hierarchy.
"""
function run_graphviz(
        io::IO, graph::AbstractString; prog::Symbol = :dot, format::String = "svg")
    prog = gv_backend(:graphviz_jll, prog)

    return open(gv -> print(gv, graph), `$prog -T$format`, io, write = true)
end

function run_graphviz(path::AbstractString, graph::AbstractString;
        prog::Symbol = :dot, format::String = "svg")
    open(path, "w+") do io
        run_graphviz(io, graph; prog, format)
    end
end