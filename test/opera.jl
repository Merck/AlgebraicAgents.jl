using Test, AlgebraicAgents
using DataStructures: enqueue!

@testset "opera interaction with two agents on different time steps" begin
    @aagent struct MyAgent{T <: Real}
        time::T
        Δt::T
        counter1::Int # counts _step
        counter1_t::Vector{T}
        counter2::Int # countes _interact!
        counter2_t::Vector{T}
    end

    function AlgebraicAgents._interact!(a::MyAgent{T}) where {T}
        a.counter2 += 1
        push!(a.counter2_t, a.time)
    end

    function AlgebraicAgents._step!(a::MyAgent{T}) where {T}
        if a.name == "alice"
            @schedule only(getagent(a, r"bob")) 0
        else
            @schedule only(getagent(a, r"alice")) 0
        end

        a.counter1 += 1
        push!(a.counter1_t, a.time)
        a.time += a.Δt
    end

    AlgebraicAgents._projected_to(a::MyAgent) = a.time

    alice = MyAgent{Float64}("alice", 0.0, 1.0, 0, Float64[], 0, Float64[])
    bob = MyAgent{Float64}("bob", 0.0, 1.5, 0, Float64[], 0, Float64[])

    joint_system = ⊕(alice, bob, name = "joint")
    simulate(joint_system, 9.0)

    @test alice.counter1 == 9
    @test alice.counter2 == 6
    @test alice.counter1_t == Float64.(0:8)
    @test alice.counter2_t == Float64.([1, 2, 4, 5, 7, 8])

    @test bob.counter1 == 6
    @test bob.counter2 == 9
    @test bob.counter1_t == collect(0:1.5:7.5)
    @test bob.counter2_t == [1.5, 1.5, 3, 4.5, 4.5, 6, 7.5, 7.5, 9]
end

@testset "opera agent call with two agents on different time steps" begin
    @aagent struct MyAgent1{T <: Real}
        time::T
        Δt::T
        counter1::Int # counts _step
        counter1_t::Vector{T}
        counter2::Int # for opera calls
        counter2_t::Vector{T} # local time when the opera call is executed
        counter2_tt::Vector{T} # time of the scheduling agent when that call was queued
    end

    function poke_other(a, t)
        a.counter2 += 1
        push!(a.counter2_t, a.time)
        push!(a.counter2_tt, t)
    end

    function AlgebraicAgents._step!(a::MyAgent1{T}) where {T}
        tnow = a.time
        if a.name == "alice"
            @schedule_call only(getagent(a, r"bob")) (a)->poke_other(a, tnow)
        else
            @schedule_call only(getagent(a, r"alice")) (a)->poke_other(a, tnow)
        end

        a.counter1 += 1
        push!(a.counter1_t, a.time)
        a.time += a.Δt
    end

    AlgebraicAgents._projected_to(a::MyAgent1) = a.time

    alice = MyAgent1{Float64}("alice", 0.0, 1.0, 0, Float64[], 0, Float64[], Float64[])
    bob = MyAgent1{Float64}("bob", 0.0, 1.5, 0, Float64[], 0, Float64[], Float64[])

    joint_system = ⊕(alice, bob, name = "joint")
    simulate(joint_system, 9.0)

    @test alice.counter1 == 9
    @test alice.counter2 == 6
    @test alice.counter1_t == Float64.(0:8)
    @test alice.counter2_t == Float64.([1, 2, 4, 5, 7, 8])
    @test alice.counter2_tt == bob.counter1_t

    @test bob.counter1 == 6
    @test bob.counter2 == 9
    @test bob.counter1_t == collect(0:1.5:7.5)
    @test bob.counter2_t == [1.5, 1.5, 3, 4.5, 4.5, 6, 7.5, 7.5, 9]
    @test bob.counter2_tt == alice.counter1_t
end

@testset "test custom AbstractOperaCall" begin

    # subtype of AbstractOperaCall which Opera can work with
    struct TwoAgentCall{A <: AbstractAlgebraicAgent, B <: AbstractAlgebraicAgent,
                        C <: Function} <: AbstractOperaCall
        agentA::A
        agentB::B
        call::C
    end

    @aagent struct MyAgent2{T <: Real, M <: AbstractString}
        time::T
        Δt::T
        myinfo::M
    end

    function interact_together(a, b)
        tmp = a.myinfo
        a.myinfo = b.myinfo
        b.myinfo = tmp
    end

    # Opera interface functions which need specialization
    function AlgebraicAgents.execute_action!(::Opera, call::TwoAgentCall)
        call.call(call.agentA, call.agentB)
    end

    function AlgebraicAgents.opera_enqueue!(opera::Opera, call::TwoAgentCall,
                                            priority::Float64 = 0.0)
        !haskey(opera.calls, call) && enqueue!(opera.calls, call => priority)
    end

    # general interface functions for MyAgent2 types
    function AlgebraicAgents._step!(a::MyAgent2{T, M}) where {T, M}
        if a.name == "alice"
            opera_enqueue!(getopera(a),
                           TwoAgentCall(a, only(getagent(a, r"bob")), interact_together))
        end

        a.time += a.Δt
    end

    AlgebraicAgents._projected_to(a::MyAgent2) = a.time

    # simulate
    alice = MyAgent2{Float64, String}("alice", 0.0, 1.0, "alice's info")
    bob = MyAgent2{Float64, String}("bob", 0.0, 1.0, "bob's info")

    joint_system = ⊕(alice, bob, name = "joint")

    @test alice.myinfo == "alice's info"
    @test bob.myinfo == "bob's info"

    simulate(joint_system, 1.0)

    @test alice.myinfo == "bob's info"
    @test bob.myinfo == "alice's info"
end
