using Test, AlgebraicAgents

@testset "@aagent macro" begin
    "docstring"
    @aagent struct BaseAgent
        mutable1::Any
        mutable2::Int
    end

    @doc (@doc BaseAgent)
    @aagent BaseAgent struct DerivedAgent
        mutable3::Any
        mutable4::Int
    end

    @test BaseAgent <: AbstractAlgebraicAgent
    @test fieldnames(BaseAgent) ==
          (:uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1, :mutable2)
    @test fieldtype(BaseAgent, :mutable2) == Int

    @test fieldnames(DerivedAgent) ==
          (:uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1,
        :mutable2, :mutable3, :mutable4)

    @test fieldtype(DerivedAgent, :mutable2) == Int
    @test fieldtype(DerivedAgent, :mutable4) == Int

    abstract type SuperAgent end
    @aagent BaseAgent SuperAgent struct DerivedAgent2 end
    @test DerivedAgent2 <: SuperAgent

    if VERSION >= v"1.8"
        @testset "@aagent macro with immutable fields" begin
            "docstring"
            @aagent struct BaseAgent_w_immutables
                mutable1::Any
                mutable2::Int

                const immutable1
                const immutable2::Int
            end

            @doc (@doc BaseAgent_w_immutables)
            @aagent BaseAgent_w_immutables struct DerivedAgent_w_immutables
                mutable3::Any
                mutable4::Int

                const immutable3
                const immutable4::Int
            end

            @test BaseAgent_w_immutables <: AbstractAlgebraicAgent
            @test fieldnames(BaseAgent_w_immutables) ==
                  (:uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1,
                :mutable2, :immutable1, :immutable2)
            @test isconst(BaseAgent_w_immutables, :immutable1)
            @test !isconst(BaseAgent_w_immutables, :mutable1)
            @test fieldtype(BaseAgent_w_immutables, :mutable2) == Int

            @test fieldnames(DerivedAgent_w_immutables) ==
                  (:uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1,
                :mutable2, :immutable1, :immutable2, :mutable3, :mutable4, :immutable3,
                :immutable4)
            @test isconst(DerivedAgent_w_immutables, :immutable1)
            @test !isconst(DerivedAgent_w_immutables, :mutable1)
            @test fieldtype(DerivedAgent_w_immutables, :mutable2) == Int

            @test isconst(DerivedAgent_w_immutables, :immutable3)
            @test !isconst(DerivedAgent_w_immutables, :mutable3)
            @test fieldtype(DerivedAgent_w_immutables, :mutable4) == Int
        end
    end

    @testset "parametric types" begin
        @aagent struct MyAgent{T <: Real, P <: Real}
            myname1::T
            myname2::P
        end

        a = MyAgent{Float64, Int}("myagent", 1, 2)
        @test a isa MyAgent{Float64, Int}
    end
end

@testset "getindex for FreeAgent" begin
    myagent = FreeAgent("root", [FreeAgent("a"), FreeAgent("b")])
    @test myagent["a"] isa AbstractAlgebraicAgent
    @test length(myagent[["a", "b"]]) == 2
    @test myagent[:] == collect(values(inners(myagent)))
    @test_throws ArgumentError myagent[1]
    @test_throws KeyError myagent["bbb"]
end

@testset "saving and loading" begin
    @aagent struct MyAgentLoadsave
        field::Any
    end

    system = MyAgentLoadsave("agent1", 1) ⊕ MyAgentLoadsave("agent2", 2)
    system_dump = AlgebraicAgents.save(system)

    @test system_dump == Dict{String, Any}("name" => "diagram",
        "inners" => Dict{String, Any}[
            Dict("name" => "agent1",
                "arguments" => [1],
                "type" => MyAgentLoadsave),
            Dict("name" => "agent2", "arguments" => [2], "type" => MyAgentLoadsave)],
        "type" => FreeAgent)

    system_reloaded = AlgebraicAgents.load(system_dump; eval_scope = @__MODULE__)

    @test system_reloaded isa FreeAgent
    @test getname(system_reloaded) == "diagram"

    @test length(inners(system_reloaded)) == 2

    agent1 = inners(system_reloaded)["agent1"]
    @test agent1 isa MyAgentLoadsave
    @test getname(agent1) == "agent1"
    @test agent1.field == 1

    system_dump["inners"][1]["type"] = "MyAgentLoadsave"
    system_reloaded = AlgebraicAgents.load(system_dump; eval_scope = @__MODULE__)
    agent1 = inners(system_reloaded)["agent1"]
    @test agent1 isa MyAgentLoadsave

    opera_dump = Dict(
        "instantious" => [
            Dict("call" => () -> println("instantious interaction"))
        ],
        "futures" => [Dict("time" => 2.0, "call" => () -> println("future"))],
        "controls" => [Dict("call" => () -> println("control"))])
    push!(system_dump, "opera" => opera_dump)
    system_reloaded = AlgebraicAgents.load(system_dump; eval_scope = @__MODULE__)

    @test length(getopera(system_reloaded).instantious_interactions) == 1
    @test length(getopera(system_reloaded).futures) == 1
    @test length(getopera(system_reloaded).controls) == 1
end
