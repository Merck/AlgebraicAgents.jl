# see https://github.com/AlgebraicJulia/Catlab.jl/blob/8d35ef724f0f0864ecdccef173eec958329f43e5/ext/CatlabGraphvizExt.jl

using .Graphviz_jll

function gv_backend(::Type{Val{:graphviz_jll}}, prog)
    getfield(Graphviz_jll, Symbol(prog))(identity)
end

let cfg = joinpath(Graphviz_jll.artifact_dir, "lib", "graphviz", "config6")
    if !isfile(cfg)
        Graphviz_jll.dot(path -> run(`$path -c`))
    end
end
