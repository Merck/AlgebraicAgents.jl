using Documenter, DocumenterMarkdown, Literate
using AlgebraicAgents

using DifferentialEquations, Agents, AlgebraicDynamics
using DataFrames, Plots

# from https://github.com/MilesCranmer/SymbolicRegression.jl/blob/master/docs/make.jl
# see discussion here https://github.com/JuliaDocs/Documenter.jl/issues/1943

design = open(joinpath(dirname(@__FILE__), "src/design.md")) do io
    read(io, String)
end

design = replace(design, r"```mermaid([^`]*)```" => s"```@raw html\n<div class=\"mermaid\">\n\1\n</div>\n```")

# init mermaid.js:
init_mermaid = """
```@raw html
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@9/dist/mermaid.esm.min.mjs';
  mermaid.initialize({ startOnLoad: true });
</script>
```
"""

design_mmd = init_mermaid * design

open(joinpath(dirname(@__FILE__), "src/design_mmd.md"), "w") do io
    write(io, design_mmd)
end
# end required for mmd

# Literate for tutorials
const literate_dir = joinpath(@__DIR__, "..", "tutorials")
const generated_dir = joinpath(@__DIR__, "src", "sketches")
const skip_dirs = ["traces", "wires"]

for (root, dirs, files) in walkdir(literate_dir)
    if any(occursin.(skip_dirs, root)) || startswith(root, "_")
        continue
    end
    out_dir = joinpath(generated_dir, relpath(root, literate_dir))
    for file in files
      f,l = splitext(file)
      if l == ".jl" && !startswith(f, "_")
        Literate.markdown(joinpath(root, file), out_dir;
          documenter=true, credit=false)
      end
    end
end

pages = [
    "index.md",
    "design_mmd.md",
    "integrations.md",
    "Sketches" => [
        "sketches/agents/agents.md",
        "sketches/molecules/molecules.md",
        "sketches/sciml/sciml.md",
        "sketches/algebraicdynamics/algebraicdynamics.md",
        "sketches/stochastic_simulation/anderson.md",
    ],
]

makedocs(sitename = "AlgebraicAgents.jl",
         format = Documenter.HTML(prettyurls = false, edit_link = "main"),
         ; pages)

deploydocs(repo = "github.com/Merck/AlgebraicAgents.jl.git")

rm(joinpath(dirname(@__FILE__), "src/design_mmd.md"))
