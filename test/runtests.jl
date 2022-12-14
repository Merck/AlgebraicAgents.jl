using SafeTestsets, BenchmarkTools

@time begin
    @time @safetestset "SciML integration tutorial" begin include("sciml/sciml_test.jl") end
    @time @safetestset "Agents.jl integration tutorial" begin include("agents/sir_test.jl") end
    @time @safetestset "toy pharma model tutorial test" begin include("molecules/test.jl") end
    @time @safetestset "AlgebraicDynamics.jl integration UWD tutorial" begin include("algebraicdynamics/test_uwd.jl") end
    @time @safetestset "AlgebraicDynamics.jl integration DWD tutorial" begin include("algebraicdynamics/test_dwd.jl") end
end