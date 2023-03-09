# Framework design

Here we describe the design principles of the AlgebraicAgents. It should be of most use to advanced users and persons interested in contributing to the software. New users are encouraged to start by reading one of the tutorials ("sketches").

## Simulation loop

We describe here the main simulation loop which steps models built in AlgebraicAgents forward in time.

AlgebraicAgents keeps agents synchronized by ensuring that the model will only simulate the agent(s) whose projected time (e.g. the maximum time for which that agent's trajectory has been solved) is the minimum of all agents. For example, if there are 3 agents, whose internal step sizes are of 1, 1.5, and 3 time units, respectively, then at the end of the first step, their projected time will be 1, 1.5, and 3 (assuming they all start at time 0). The simulation will find the minimum of those times and only simulate the agent(s) whose projected time(s) are equal to the minimum. In this case, it is the first agent, who is now projected to time 2 on the second step (other agents are not simulated). Now, the new minimum time is 1.5, and the second agent is projected to time 3 on the third step, etc. The simulation continues until all agents have been projected to their final time point, or the minimum of projected times reaches a maximum time horizon. If all agents take time steps of the same size, then they will all be updated each global step.

There are several functions in the interface for an [`AbstractAlgebraicAgent`](@ref) which implement these dynamics. When defining new agent types, one should implement the [`AlgebraicAgents._step!`](@ref) method, which will step that agent forward if its projected time is equal to the least projected time, among all agents in the hierarchy. Agent types also need to implement [`AlgebraicAgents._projected_to`](@ref), which is crucial to keeping the simulation synchronized. It will return:

  * `nothing` if the agent does not implement its own `_step!` rule (e.g. [`FreeAgent`](@ref) which is a container of agents)
  * `true` if the agent has been projected to the final time point (`_step!` will not be called again)
  * a value of `Number`, giving the time point to which the agent has been projected

These are collected into `ret`, which is an object that will be `true` if and only if all agents have returned `true`, and is otherwise the minimum of the numeric values (projection times) returned from each inner agent's step.

```mermaid
flowchart TD

    Start((Enter Program))-->Project[Set t equal to minimum \n projected time]:::GreenNode

    Project-->RootDecision1{is root?}:::YellowNode
    
    RootDecision1 -->|yes| PreWalk[Prestep inner agents]:::GreenNode

    RootDecision1 -->|no| Step[Step inner agents]:::GreenNode

    PreWalk -.->|_prestep!| Inners([<:AbstractAlgebraicAgent]):::RedNode
    
    PreWalk --> Step

    Step -.->|step!| Inners

    subgraph inners
    Inners
    end

    Ret([ret]):::RedNode

    Inners -.->|_projected_to| Ret

    Step --> LocalDecision{local projected time == t\n equals the min projected time}:::YellowNode

    LocalDecision -->|yes| LocalStep[Local step]:::GreenNode
    LocalDecision -->|no| RootDecision2{is root?}:::YellowNode

    LocalStep -.->|_projected_to| Ret

    LocalStep --> RootDecision2

    subgraph Opera

    RootDecision2 -->|yes| InstantOpera[Execute instantaneous interactions]:::GreenNode
    InstantOpera --> FutureOpera[Execute delayed interactions]:::GreenNode
    FutureOpera --> ControlOpera[Execute control interactions]:::GreenNode
    end

    Opera -.->|_projected_to| Ret

    RootDecision2 -->|no| Stop

    ControlOpera --> Stop((Exit program and\n return ret))

    classDef GreenNode fill:#D5E8D4,stroke:#82B366;
    classDef RedNode fill:#F8CECC,stroke:#B85450;
    classDef YellowNode fill:#FFE6CC,stroke:#D79B00;
```

Above we show a caricature of the main simulation loop. "Enter program" corresponds to the call to `simulate`, the value of `ret` is (typically) initialized to `0.0`. The simulation continues to step while `ret` is not `true` (meaning the maximum time horizon has been reached by the slowest agent), or has not exceeded some maximum. 

The inner area enclosed by a dashed border represents where program control is given to the `step!` method. The root agent applies `_prestep!` recurvisely to all of its inner (enclosed) agents. After this, `step!` is then applied to all inner agents, and `ret` is updated by each of them. Then the agent applies its own local update `_step!` if its own projected time is equal to the minimum of all inner agent projected times (not shown). Then the Opera module for additional interactions is called for the root agent.

## Opera

The Opera system allows interactions between agents to be scheduled. By default, AlgebraicAgents.jl provides support for three types of interactions:

  * **futures (delayed interactions)**
  * **system controls**
  * **instantious interactions**
  
For more details, see the API documentation of [`Opera`](@ref) and our tests.

### Futures
You may schedule function calls, to be executed at predetermined points of time.
An action is modeled as a tuple `(id, call, time)`, where `id` is an optional textual identifier of the action and `call` is a (parameterless) anonymous function, which will be called at the given `time`.
Once the action is executed, the return value with corresponding action id and execution time is added to `futures_log` field of `Opera` instance.

See [`add_future!`](@ref) and [`@future`](@ref).

#### Example

```julia
alice = MyAgentType("alice")
interact = agent -> wake_up!(agent)
@future alice 5.0 interact(alice) "alice_schedule"
```

The solver will stop at `t=5` and call the function `() -> interact(alice)` (a closure is taken at the time when `@future` is invoked). This interaction is identified as `"alice_schedule"`.

### Control Interactions
You may schedule control function calls, to be executed at every step of the model.
An action is modeled as a tuple `(id, call)`, where `id` is an optional textual identifier of the action, and `call` is a (parameterless) anonymous function.
Once the action is executed, the return value with corresponding action id and execution time is added to `controls_log` field of `Opera` instance.

See [`add_control!`](@ref) and [`@control`](@ref).

#### Example

```julia
system = MyAgentType("system")
control = agent -> agent.temp > 100 && cool!(agent)
@control system control(system) "temperature control"
```

At each step, the solver will call the function `() -> control(system)` (a closure is taken at the time when `@future` is invoked).

### Instantious Interactions
You may schedule additional interactions which exist within a single step of the model;
such actions are modeled as named tuples `(id, priority=0., call)`. Here, `call` is a (parameterless) anonymous function.

They exist within a single step of the model and are executed after the calls
to `_prestep!` and `_step!` finish, in the order of the assigned priorities.

In particular, you may schedule interactions of two kinds:
 
 - `poke(agent, priority)`, which will translate into a call `() -> _interact!(agent)`, with the specified priority,
 - `@call opera expresion priority`, which will translate into a call `() -> expression`, with the specified priority.

See [`poke`](@ref) and [`@call`](@ref).

#### Examples

```julia
# `poke`
poke(agent, 1.) # call `_interact!(agent)`; this call is added to the instantious priority queue with priority 1
```

```julia
# `@call`
bob_agent = only(getagent(agent, r"bob"))
@call agent wake_up(bob_agent) # translates into `() -> wake_up(bob_agent)` with priority 0
```