using Documenter, DocumenterMarkdown, Literate
using AlgebraicAgents

using DifferentialEquations, Agents, AlgebraicDynamics
using DataFrames, Plots

# from https://github.com/MilesCranmer/SymbolicRegression.jl/blob/master/docs/make.jl
# see discussion here https://github.com/JuliaDocs/Documenter.jl/issues/1943

# required for mmd
design = open(dirname(@__FILE__) * "/src/design.md") do io
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

open(dirname(@__FILE__) * "/src/design_mmd.md", "w") do io
    write(io, design_mmd)
end
# end required for mmd

pages = [
    "index.md",
    "design_mmd.md",
    "Integrations" => [
        "integrations/AgentsIntegration.md",
        "integrations/SciMLIntegration.md",
        "integrations/AlgebraicDynamicsIntegration.md",
    ],
    "Three Sketches" => [
        "sketches/agents.md",
        "sketches/pharma.md",
        "sketches/sciml.md",
        "sketches/algebraicdynamics.md",
    ],
]

makedocs(sitename = "AlgebraicAgents.jl",
         format = Documenter.HTML(prettyurls = false, edit_link = "main"),
         ; pages)

deploydocs(repo = "github.com/Merck/AlgebraicAgents.jl.git")

# cleanup the mmd doc
rm(dirname(@__FILE__) * "/src/design_mmd.md")