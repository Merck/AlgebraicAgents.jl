using AlgebraicAgents

# Define a simple hierarchy.

@aagent struct MyAgent end

alice = MyAgent("alice")
alice1 = MyAgent("alice1")
entangle!(alice, alice1)

bob = MyAgent("bob")
bob1 = MyAgent("bob1")
entangle!(bob, bob1)

joint_system = ⊕(alice, bob, name = "joint system")

# Add wires.
add_wire!(joint_system; from=alice, to=bob, from_var_name="alice_x", to_var_name="bob_x")
add_wire!(joint_system; from=bob, to=alice, from_var_name="bob_y", to_var_name="alice_y")

add_wire!(joint_system; from=alice, to=alice1, from_var_name="alice_x", to_var_name="alice1_x")
add_wire!(joint_system; from=bob, to=bob1, from_var_name="bob_x", to_var_name="bob1_x")

# Show wires.
get_wires_from(alice)
get_wires_to(alice1)

# Retrieve variables along input wires.
AlgebraicAgents.getobservable(a::MyAgent, args...) = getname(a)

retrieve_input_vars(alice1)

# Plot wires.
graph1 = wiring_diagram(joint_system)

graph2 = wiring_diagram(joint_system; parentship_edges=false)

graph3 = wiring_diagram([alice, alice1, bob, bob1])

graph4 = wiring_diagram([[alice, alice1], [bob, bob1]])

graph5 = wiring_diagram([[alice, alice1], [bob, bob1]]; group_labels=["alice", "bob"], parentship_edges=false)

# using Graphviz_jll

run_graphviz("graph5.svg", graph5)

# Delete wires.
delete_wires!(joint_system; from=alice, to=alice1)