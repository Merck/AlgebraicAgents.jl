# sums of agents

"""
    ⊕(models::Vararg{AbstractAlgebraicAgent, N}; name)
Algebraic sum of algebraic models. Optionally specify resulting model's name.

By default, outputs an instance of `FreeAgent`.

# Examples
```julia
⊕(m1, m2; name="diagram1") ⊕ ⊕(m3, m4; name="diagram2");
```
"""
function ⊕(models::Vararg{AbstractAlgebraicAgent, N}; name = "diagram") where {N}
    diagram = FreeAgent(name) # empty diagram

    # insert inner agents
    for model in models
        entangle!(diagram, model)
    end

    diagram
end

"
    @sum models...

Perform an algebraic sum of algebraic models (flatten arguments to ⊕).

# Examples
```julia
@sum m1 m2 m3 m4 # == ⊕(m1, m2, m3, m4)
```
"
macro sum(models...)
    :(⊕($(esc.(models)...)))
end
