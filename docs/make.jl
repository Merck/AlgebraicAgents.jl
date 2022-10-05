using Documenter, DocumenterMarkdown
using AlgebraicAgents

add_integration(:AgentsIntegration); using AgentsIntegration
add_integration(:SciMLIntegration); using SciMLIntegration

pages = [
    "index.md",
    "Integrations" => ["integrations/AgentsIntegration.md", "integrations/SciMLIntegration.md"],
    "Three Sketches" => ["sketches/agents.md", "sketches/pharma.md", "sketches/sciml.md"]
]

makedocs(sitename="AlgebraicAgents.jl", build="build_html",
    format = Documenter.HTML(prettyurls = false, edit_link=nothing), workdir=joinpath(@__DIR__, ".."); pages
)

makedocs(sitename="AlgebraicAgents.jl", build="build_md",
    format = Markdown(), workdir=joinpath(@__DIR__, ".."); pages
)