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

makedocs(sitename = "AlgebraicAgents.jl", build = "build_html",
         format = Documenter.HTML(prettyurls = false, edit_link = nothing),
         workdir = joinpath(@__DIR__, ".."); pages)

#=
makedocs(sitename="AlgebraicAgents.jl", build="build_md",
    format = Markdown(), workdir=joinpath(@__DIR__, ".."); pages
)
=#
