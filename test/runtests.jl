using SafeTestsets, BenchmarkTools

@time begin
    @time @safetestset "`@aagent` macro tests" begin include("agents.jl") end
    @time @safetestset "Opera tests" begin include("opera.jl") end
    @time @safetestset "utils tests" begin include("utils.jl") end
    @time @safetestset "integrations test: SciML" begin include("integrations/sciml_test.jl") end
    @time @safetestset "integrations test: Agents.jl" begin include("integrations/agents_test.jl") end
    @time @safetestset "integrations test: AlgebraicDynamics.jl" begin include("integrations/algebraicdynamics_test.jl") end
end
