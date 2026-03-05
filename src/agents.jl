# adapted content from Agents.jl/src/core/agents.jl

"""
    define_agent(base_type, super_type, type, __module, constructor)
A function to define an agent type. See the definition of [`@aagent`](@ref).
"""
function define_agent(base_type, super_type, type, __module, constructor)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912

    extra_fields = MacroTools.striplines(type.args[3])
    new_name = type.args[2]
    namified = Docs.namify(new_name)

    # Resolve base type at macro expansion time and check common fields.
    resolved_base = Core.eval(__module, base_type)
    if !all(f -> f ∈ fieldnames(resolved_base), common_fields_agent)
        error("type $resolved_base does not implement common interface fields $common_fields_agent")
    end

    # Collect field names and types from the base type at macro expansion time.
    base_fnames = fieldnames(resolved_base)
    base_ftypes = getproperty(resolved_base, :types)
    base_fields = map(zip(base_fnames, base_ftypes)) do x
        f, T = x # due to https://github.com/Merck/AlgebraicAgents.jl/issues/38
        if (VERSION < v"1.8") || !(isconst(resolved_base, f))
            :($f::$T)
        else
            Expr(:const, :($f::$T))
        end
    end

    # Resolve super type at macro expansion time.
    resolved_super = Core.eval(__module, super_type)

    # Build and evaluate the struct definition during macro expansion.
    # This ensures the type binding exists in an earlier world age so that
    # Core.@__doc__ (and any subsequent code) can access it without
    # triggering Julia 1.12+ world-age errors.
    struct_expr = quote
        mutable struct $new_name <: $resolved_super
            $(base_fields...)
            $(extra_fields.args...)
            $constructor
        end
    end
    Base.eval(__module, struct_expr)

    # The struct is already defined. Return @__doc__ for documentation support.
    # No world-age issue: the binding was created during macro expansion (earlier world).
    quote
        Core.@__doc__ $(esc(namified))
        nothing
    end
end

"""
    @aagent [OptionalBasetype=FreeAgent] [OptionalSupertype=AbstractAlgebraicAgent] struct my_agent
        extra_fields...
    end

Define a custom agent type, and include fields expected by default interface methods (see [`FreeAgent`](@ref)).

Fields are mutable by default, but can be declared immutable using `const` keyword.

Provides a constructor which takes agent's name at the input, and populates the common fields.

# Example 
```julia
@aagent struct Molecule
    age::Float64
    birth_time::Float64
    sales::Float64
end
```

Optional base type:
```julia
@aagent FreeAgent struct Molecule
    age::Float64
    birth_time::Float64
    sales::Float64
end
```

Optional base type and a super type:
```julia
@aagent FreeAgent AbstractMolecule struct Molecule
    age::Float64
    birth_time::Float64
    sales::Float64
end
```

Parametric types:
```julia
@aagent struct MyAgent{T <: Real, P <: Real}
    field1::T
    field2::P
end

MyAgent{Float64, Int}("myagent", 1, 2)
```
"""
macro aagent(type)
    aagent(FreeAgent, AbstractAlgebraicAgent, type, __module__)
end

macro aagent(base_type, type)
    aagent(base_type, AbstractAlgebraicAgent, type, __module__)
end

macro aagent(base_type, super_type, type)
    aagent(base_type, super_type, type, __module__)
end

const common_fields_agent = (:uuid, :name, :parent, :inners, :relpathrefs, :opera)

# implements `@aagent` macro; the base type should contain the common interface fields
function aagent(base_type, super_type, type, __module)
    tname, param_tnames_constraints = get_param_tnames(type)
    tname_plain = tname isa Symbol ? tname : tname.args[1]

    define_agent(base_type, super_type, type, __module,
        quote
            function $(tname)(name::AbstractString,
                    args...) where {
                    $(param_tnames_constraints...),
            }
                uuid = AlgebraicAgents.uuid4()
                inners = Dict{String, AbstractAlgebraicAgent}()
                relpathrefs = Dict{AbstractString,
                    AlgebraicAgents.UUID}()
                opera = AlgebraicAgents.Opera()

                # if an extra field is missing, provide better error message
                extra_fields = setdiff(fieldnames($tname_plain),
                    $common_fields_agent)
                if length(args) != length(extra_fields)
                    error("""the agent type $($tname_plain) default constructor `$($tname_plain)(name, args...)` expects $(length(extra_fields)) arguments for custom fields $extra_fields, but $(length(args)) arguments were given.

                          If you intended to call a custom constructor and you passed a string as the first variable, please check that the custom constructor declares the type of the first positional argument to be `AbstractString` (so that dynamic dispatch works).
                          """)
                end

                # initialize agent
                agent = new(uuid, name, nothing, inners, relpathrefs,
                    opera, args...)
                # push ref to opera
                push!(agent.opera.directory, agent.uuid => agent)

                agent
            end
        end)
end

# by @slwu89, issue #3
"Extract type names and type constraints from struct definition."
function get_param_tnames(type)
    name = type.args[2]
    if name isa Symbol
        name, []
    else
        param_tnames = map(name.args[2:end]) do x
            if x isa Symbol
                return x
            else
                return x.args[1]
            end
        end # like T,L

        param_tnames_constraints = name.args[2:end]# like T<:Number,L<:Real
        tname = :($(name.args[1]){$(param_tnames...)})

        tname, param_tnames_constraints
    end
end

"Populate common interface fields of an agent, incl. `uuid`, `parent`, `relpathrefs`, and `opera`."
function setup_agent!(agent::AbstractAlgebraicAgent, name::AbstractString)
    agent.name = name
    agent.uuid = AlgebraicAgents.uuid4()

    agent.parent = nothing
    agent.inners = Dict{String, AbstractAlgebraicAgent}()
    agent.relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
    agent.opera = AlgebraicAgents.Opera(agent.uuid => agent)

    agent
end
