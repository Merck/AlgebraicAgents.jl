using Test, AlgebraicAgents

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
            poke(only(getagent(a, r"bob")))
        else
            poke(only(getagent(a, r"alice")))
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
            @call a poke_other(only(getagent(a, r"bob")), tnow)
        else
            @call a poke_other(only(getagent(a, r"alice")), tnow)
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

@testset "futures" begin
    @aagent struct MyAgent2{T <: Real}
        time::T
        Δt::T

        max_time::T
    end

    # future: call
    interact = agent -> agent

    function AlgebraicAgents._step!(a::MyAgent2{T}) where {T}
        a.time += a.Δt
    end

    AlgebraicAgents._projected_to(a::MyAgent2) = a.time >= a.max_time ? true : a.time

    alice = MyAgent2{Float64}("alice", 0.0, 1.0, 10.0)
    bob = MyAgent2{Float64}("bob", 0.0, 1.5, 15.0)

    joint_system = ⊕(alice, bob, name = "joint")

    @future alice 5.0 interact(alice) "alice_schedule"
    @future bob 20.0 interact(bob)

    simulate(joint_system, 100.0)

    opera = getopera(joint_system)

    @test isempty(opera.futures)
    @test length(opera.futures_log) == 2
    @test opera.futures_log[1].retval == alice
    @test opera.futures_log[2].retval == bob
end

@testset "control interactions" begin
    @aagent struct MyAgent3{T <: Real}
        time::T
        Δt::T

        max_time::T
    end

    # control
    control = function (model::AbstractAlgebraicAgent)
        projected_to(model)
    end

    control_alice = agent -> getname(agent)

    function AlgebraicAgents._step!(a::MyAgent3{T}) where {T}
        a.time += a.Δt
    end

    AlgebraicAgents._projected_to(a::MyAgent3) = a.time >= a.max_time ? true : a.time

    alice = MyAgent3{Float64}("alice", 0.0, 1.0, 10.0)
    bob = MyAgent3{Float64}("bob", 0.0, 1.5, 15.0)

    joint_system = ⊕(alice, bob, name = "joint")

    @control alice control_alice(alice) "control_alice"
    @control joint_system control(joint_system)

    simulate(joint_system, 100.0)

    opera = getopera(joint_system)

    @test length(opera.controls) == 2
    @test length(opera.controls_log) == 32
    @test opera.controls_log[1].retval == "alice"
    @test opera.controls_log[2].retval == 1.0
end
