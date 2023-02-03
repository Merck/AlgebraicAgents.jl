using Test, AlgebraicAgents

@testset "typetree_mmd" begin
    tt = typetree_mmd(Int64)
    @test length(tt) == 2
    @test tt[2] == "class Int64\n"

    tt1 = typetree_mmd(Int64, Integer)
    @test tt1[2] == "Integer <|-- Int64\n"
end
