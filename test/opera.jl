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
            poke(only(getagent(a, r"bob")), 0.0)
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

    joint_system = ⊕(alice, bob, name = "joint system")
    simulate(joint_system, 9.0)

    @test alice.counter1 == 9
    @test alice.counter2 == 6
    @test alice.counter1_t == Float64.(0:8)
    @test alice.counter2_t == Float64.([1, 2, 4, 5, 7, 8])

    @test bob.counter1 == 6
    @test bob.counter2 == 9
    @test bob.counter1_t == collect(0:1.5:7.5)
    @test bob.counter2_t == [1.5, 1.5, 3, 4.5, 4.5, 6, 7.5, 7.5, 9]

    opera = getopera(joint_system)
    @test length(opera.instantious_interactions_log) == 15
    @test opera.instantious_interactions_log[1].id == "instantious_1"
    @test opera.instantious_interactions_log[2].id == "instantious_2"

    # check if operas get out of sync after disentangling the agents
    disentangle!(alice)
    add_instantious!(alice, () -> nothing)
    add_instantious!(alice, () -> nothing, 0)
    add_instantious!(bob, () -> nothing, 0)

    @test length(getopera(alice).instantious_interactions) == 2
    @test length(getopera(bob).instantious_interactions) == 1

    @test getopera(alice).instantious_interactions[1].id == "instantious_17"
    @test getopera(alice).instantious_interactions[2].id == "instantious_16"
    @test getopera(bob).instantious_interactions[1].id == "instantious_16"
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

@testset "wires" begin
    @aagent struct MyAgent4 end

    alice = MyAgent4("alice")
    alice1 = MyAgent4("alice1")
    entangle!(alice, alice1)

    bob = MyAgent4("bob")
    bob1 = MyAgent4("bob1")
    entangle!(bob, bob1)

    joint_system = ⊕(alice, bob, name = "joint system")

    # Add wires.
    add_wire!(joint_system;
        from = alice,
        to = bob,
        from_var_name = "alice_x",
        to_var_name = "bob_x")
    add_wire!(joint_system;
        from = bob,
        to = alice,
        from_var_name = "bob_y",
        to_var_name = "alice_y")

    add_wire!(joint_system;
        from = alice,
        to = alice1,
        from_var_name = "alice_x",
        to_var_name = "alice1_x")
    add_wire!(joint_system;
        from = bob,
        to = bob1,
        from_var_name = "bob_x",
        to_var_name = "bob1_x")

    # Show wires.
    @test length(get_wires_from(alice)) == 2
    @test length(get_wires_to(alice1)) == 1

    # Retrieve variables along input wires.
    AlgebraicAgents.getobservable(a::MyAgent4, args...) = getname(a)

    @test retrieve_input_vars(alice1) == Dict("alice1_x" => "alice")

    # Delete wires.
    @test length(delete_wires!(joint_system; from = alice, to = alice1)) == 3
end

@testset "concepts and relations" begin
    # Instantiate two agents
    client = FreeAgent("client")
    server = FreeAgent("server")

    # Create a system (the “universe” in which they interact)
    network_system = ⊕(client, server, name="System")

    # ----- Communication wires -----

    # Client sends a request to Server
    add_wire!(network_system;
        from = client,
        to = server,
        from_var_name = "request_payload",
        to_var_name = "incoming_request"
    )

    # Server sends a response back to Client
    add_wire!(network_system;
        from = server,
        to = client,
        from_var_name = "response_payload",
        to_var_name = "incoming_response"
    )

    # ----- Define generic Concepts -----

    c_data = Concept("Data", Dict(:format => "binary")) # abstract container
    c_request = Concept("Request", Dict(:purpose => "query")) # a kind of Data
    c_response = Concept("Response", Dict(:purpose => "reply")) # a kind of Data

    # Bind all Concepts into our system
    add_concept!.(Ref(network_system), [c_data, c_request, c_response])

    # ----- Concept hierarchy -----

    # Request ⊂ Data
    add_relation!(c_request, c_data, :is_a)
    # Response ⊂ Data
    add_relation!(c_response, c_data, :is_a)

    # ----- Set up Agent–Concept relations -----

    # Client produces requests and consumes responses
    add_relation!(client, c_request,  :produces)
    add_relation!(client, c_response, :consumes)

    # Server consumes requests and produces responses
    add_relation!(server, c_request,  :consumes)
    add_relation!(server, c_response, :produces)

    # Print out the concepts.
    for r in server.opera.concepts
        println(r)
    end

    # Print out the the relations.
    for r in server.opera.relations
        println(r)
    end

    # Query related concepts/agents
    println("Entities related to Data:")
    for r in get_relations(c_data)
        println(r)
    end

    println("Entites that Client produces:")
    for r in get_relations(client, :produces)
        println(r)
    end

    @test length(server.opera.concepts) == 3
    @test length(server.opera.relations) == 6
    @test length(get_relations(c_data)) == 2
    @test length(get_relations(client, :produces)) == 1
    @test isrelated(client, c_request, :produces) == true

    # ----- Visualize the wires and relations -----

    # Visualize the wiring diagram of the system
    wiring_diagram(network_system)

    # Visualize the concept graph of the system
    concept_graph(get_relation_closure(server))

    # ----- Manipulate relations and concepts -----

    # Remove the concept-to-concept relation
    remove_relation!(c_data, c_request, :is_a)

    # Remove the Fruit concept entirely
    remove_concept!(server, c_request)

    @test length(server.opera.concepts) == 2
    @test length(server.opera.relations) == 3
end