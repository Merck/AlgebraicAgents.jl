using Test, AlgebraicAgents

@testset "@aagent macro" begin
    "docstring"
    @aagent struct BaseAgent
        mutable1
        mutable2::Int
    end
    
    @doc (@doc BaseAgent)
    @aagent BaseAgent struct DerivedAgent
        mutable3
        mutable4::Int
    end

    @test BaseAgent <: AbstractAlgebraicAgent
    @test fieldnames(BaseAgent) == (:uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1, :mutable2)
    @test fieldtype(BaseAgent, :mutable2) == Int

    @test fieldnames(DerivedAgent) == (
        :uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1, 
        :mutable2, :mutable3, :mutable4
    )

    @test fieldtype(DerivedAgent, :mutable2) == Int
    @test fieldtype(DerivedAgent, :mutable4) == Int

    abstract type SuperAgent end
    @aagent BaseAgent SuperAgent struct DerivedAgent2 end
    @test DerivedAgent2 <: SuperAgent

    if VERSION >= v"1.8"
        @testset "@aagent macro with immutable fields" begin
            "docstring"
            @aagent struct BaseAgent_w_immutables
                mutable1
                mutable2::Int

                const immutable1
                const immutable2::Int
            end
            
            @doc (@doc BaseAgent_w_immutables)
            @aagent BaseAgent_w_immutables struct DerivedAgent_w_immutables
                mutable3
                mutable4::Int

                const immutable3
                const immutable4::Int
            end

            @test BaseAgent_w_immutables <: AbstractAlgebraicAgent
            @test fieldnames(BaseAgent_w_immutables) == (
                :uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1,
                :mutable2, :immutable1, :immutable2
            )
            @test isconst(BaseAgent_w_immutables, :immutable1)
            @test !isconst(BaseAgent_w_immutables, :mutable1)
            @test fieldtype(BaseAgent_w_immutables, :mutable2) == Int

            @test fieldnames(DerivedAgent_w_immutables) == (
                :uuid, :name, :parent, :inners, :relpathrefs, :opera, :mutable1, 
                :mutable2, :immutable1, :immutable2, :mutable3, :mutable4, :immutable3,
                :immutable4
            )
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