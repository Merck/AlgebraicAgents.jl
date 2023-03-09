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
    hierarchy = agent_hierarchy_mmd(base)
    @test hierarchy[1] == "classDiagram\n"
    @test hierarchy[2] == "class agent1\n"
    @test hierarchy[end] == "agent1 <|-- agent3\n"

    # uuid
    hierarchy = agent_hierarchy_mmd(base; use_uuid = 2)

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

@testset "queries" begin
    @aagent struct MyPropertyAgent{T}
        property::T
    end

    agents = map(i -> MyPropertyAgent{Int}("agent$i", i), 1:10)
    container = FreeAgent("free-agent", agents)

    filter1 = filter(container, f"_.property > 2", f"_.property < 9")
    @test length(filter1) == 6

    filter2 = container |> @filter(_.property<3) |> @filter(f"_.property > 1")
    @test only(filter2) == agents[2]

    transform1 = transform(container, TransformQuery("query", a -> a.name),
                           TransformQuery("index", a -> a.property))
    @test all(x -> keys(x) == (:uuid, :query, :index), transform1)
    @test sort(map(x -> x.index, transform1)) == collect(1:10)

    transform2 = container |> @transform(_.name, index=_.property)
    @test all(x -> keys(x) == (:uuid, :query_1, :index), transform2)
    @test sort(map(x -> x.index, transform2)) == collect(1:10)
end
