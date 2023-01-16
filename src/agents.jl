# adapted content from Agents.jl/src/core/agents.jl

"""
    define_agent(base_type, super_type, type, __module, constructor)
A function to define an agent type. See the definition of [`@aagent`](@ref).
"""
function define_agent(base_type, super_type, type, __module, constructor)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912

    # We start with a quote. All macros return a quote to be evaluated
    extra_fields = MacroTools.striplines(type.args[3])
    new_name = type.args[2]
    quote
        let
            # Here we collect the field names and types from the base type
            # Because the base type already exists, we escape the symbols to obtain it
            base_fieldnames = fieldnames($(esc(base_type)))
            base_fieldtypes = [t for t in getproperty($(esc(base_type)), :types)]
            base_fields = map(zip(base_fieldnames, base_fieldtypes)) do (f, T)
                if (VERSION < v"1.8") || !(isconst($(esc(base_type)), f))
                    :($f::$T)
                else
                    Expr(:const, :($f::$T))
                end
            end
            # Then, we prime the additional name and fields into QuoteNodes
            # We have to do this to be able to interpolate them into an inner quote.
            name = $(QuoteNode(new_name))
            additional_fields = $(QuoteNode(extra_fields.args))

            # Now we start an inner quote. This is because our macro needs to call `eval`
            # However, this should never happen inside the main body of a macro
            # There are several reasons for that, see the cited discussion at the top
            expr = quote
                # Also notice that we escape supertype and interpolate it twice
                # because this is expected to already be defined in the calling module
                mutable struct $name <: $$(esc(super_type))
                    $(base_fields...)
                    $(additional_fields...)

                    $$(QuoteNode(constructor))
                end
            end
            # it is important to evaluate the macro in the module of the toplevel eval
            Base.eval($__module, expr)
        end

        Core.@__doc__($(esc(Docs.namify(new_name))))
        nothing
    end
end

"""
    @aagent [OptionalBasetype=FreeAgent] [OptionalSupertype=AbstractAlgebraicAgent] struct my_agent
        extra_fields...
    end

Create a custom algebraic agent type, and include fields expected by default interface methods (see [`FreeAgent`](@ref)).

Fields are mutable by default, but can be made immutable using `const` keyword.

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

const common_interface_fields = (:uuid, :name, :parent, :inners, :relpathrefs, :opera)

# implements `@aagent` macro; the base type should contain the common interface fields
function aagent(base_type, super_type, type, __module)
    tname, param_tnames_constraints = get_param_tnames(type)
    tname_plain = tname isa Symbol ? tname : tname.args[1]

    constructor = define_agent(base_type, super_type, type, __module, quote
        function $(tname)(name::AbstractString, args...) where $(param_tnames_constraints...)
                uuid = AlgebraicAgents.uuid4(); inners = Dict{String, AbstractAlgebraicAgent}()
                relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
                opera = AlgebraicAgents.Opera()

                # if an extra field is missing, provide better error message
                extra_fields = setdiff(fieldnames($tname_plain), $common_interface_fields)
                if length(args) != length(extra_fields)
                    @error "agent type $($tname_plain) expects fields $extra_fields, but only $(length(args)) were given"
                end

                # initialize agent
                agent = new(uuid, name, nothing, inners, relpathrefs, opera, args...)
                # push ref to opera
                push!(agent.opera.directory, agent.uuid => agent)

                agent
            end
        end
    )

    quote
        # check if the base type implements the common interface fields
        check = quote
            if !all(f -> f ∈ fieldnames($$(esc(base_type))), $$(common_interface_fields))
                @error "type $($$(esc(base_type))) does not implement common interface fields $($$(common_interface_fields))"
            end
        end 
        Base.eval($__module, check)

        # type constructor
        $constructor
    end
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

"Populate common interface fields of an algebraic agent, incl. `uuid`, `parent`, `relpathrefs`, and `opera`."
function setup_agent!(agent::AbstractAlgebraicAgent, name::AbstractString)
    agent.name = name; agent.uuid = AlgebraicAgents.uuid4()
    
    agent.parent = nothing; agent.inners = Dict{String, AbstractAlgebraicAgent}()
    agent.relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
    agent.opera = AlgebraicAgents.Opera(agent.uuid => agent)

    agent
end