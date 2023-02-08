using Test, AlgebraicAgents

module MyModule
abstract type MySuperType end
abstract type MySubType <: MySuperType end
end

@testset "typetree_mmd" begin
    tt = typetree_mmd(Int64)
    @test length(tt) == 2
    @test tt[2] == "class Int64\n"

    tt1 = typetree_mmd(Int64, Integer)
    @test tt1[2] == "Integer <|-- Int64\n"

    typetree_mmd(MyModule.MySuperType, rem = false)[6] ==
    "MyModule.MySuperType <|-- MyModule.MySubType\n"
    typetree_mmd(MyModule.MySuperType, rem = true)[6] == "MySuperType <|-- MySubType\n"
end
