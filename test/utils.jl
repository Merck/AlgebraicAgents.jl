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

@aagent FreeAgent struct AgentType1 end

@testset "agent_hierarchy_mmd" begin
    base = FreeAgent("agent1")
    entangle!(base, AgentType1("agent2"))
    entangle!(base, AgentType1("agent3"))

    # no uuid
    hierarchy = prewalk_ret(agent_hierarchy_mmd, base)
    hierarchy = cat(hierarchy..., dims = 1)
    @test hierarchy[1] == "classDiagram\n"
    @test hierarchy[2] == "class agent1\n"
    @test hierarchy[end] == "agent1 <|-- agent3\n"

    # uuid
    hierarchy = prewalk_ret(a -> agent_hierarchy_mmd(a, use_uuid = 2), base)
    hierarchy = cat(hierarchy..., dims = 1)

    @test occursin(r"[0-9]{2}", hierarchy[2][(end - 2):(end - 1)])
    @test occursin(r"[0-9]{2}", hierarchy[3][(end - 2):(end - 1)])
end

@testset "postwalk and prewalk with return vals" begin
    base = FreeAgent("agent1")
    entangle!(base, AgentType1("agent2"))
    entangle!(base, AgentType1("agent3"))

    ret = prewalk_ret((a) -> a.name, base)
    ret == ["agent1", "agent2", "agent3"]

    ret = postwalk_ret((a) -> a.name, base)
    ret == ["agent2", "agent3", "agent1"]
end
