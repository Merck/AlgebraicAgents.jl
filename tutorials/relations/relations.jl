using AlgebraicAgents

# This example demonstrates how to define and manipulate relations between agents and concepts
# in the AlgebraicAgents framework, and how to visualize these relations.
# We also demonstrate the concept of wires. Consider `wires.jl` for a more comprehensive example.

# ----- Define a simple hierarchy -----

# Instantiate two agents
client = FreeAgent("client")
server = FreeAgent("server")

# Create a system (the “universe” in which they interact)
system = ⊕(client, server, name="System")

# ----- Communication wires -----

# Client sends a request to Server
add_wire!(system;
    from = client,
    to = server,
    from_var_name = "request_payload",
    to_var_name = "incoming_request"
)

# Server sends a response back to Client
add_wire!(system;
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
add_concept!.(Ref(system), [c_data, c_request, c_response])

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

isrelated(client, c_request, :produces) == true

# ----- Visualize the wires and relations -----

# Visualize the wiring diagram of the system
wiring_diagram(system)

# Visualize the concept graph of the system
concept_graph(get_relation_closure(server))

# ----- Manipulate relations and concepts -----

# Remove the concept-to-concept relation
remove_relation!(c_data, c_request, :is_a)

# Remove the Fruit concept entirely
remove_concept!(server, c_request)