using Documenter, DocumenterMarkdown
using AlgebraicAgents

using DifferentialEquations, Agents, AlgebraicDynamics
using DataFrames, Plots

pages = [
    "index.md",
    "design.md",
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
