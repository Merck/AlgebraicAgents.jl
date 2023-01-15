# adapted content from Agents.jl/src/core/agents.jl

"""
    define_agent(base_type, super_type, type, __module, constructor)
A function to create agent type constructor in convenient macro form.
See the definition of [`@aagent`](@ref).
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
            additional_fieldnames = [Meta.isexpr(f, :(::)) ? f.args[1] : f for f in $(QuoteNode(extra_fields.args))]
            
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
            Core.eval($(__module), expr)
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
@aagent Molecule begin
    age::Float64
    birth_time::Float64
    kill_time::Float64

    mol::AbstractString
    profile::NTuple{N, Float64}

    sales::Float64
    df_sales::DataFrame
end
```
"""
macro aagent(type)
    define_agent(FreeAgent, AbstractAlgebraicAgent, type, __module__, quote
            function $(type.args[2])(name::Vararg{<:AbstractString})
                m = new()
                !isempty(name) && (m.name = first(name)); m.uuid = AlgebraicAgents.uuid4()
                m.parent = nothing; m.inners = Dict{String, AbstractAlgebraicAgent}()
                m.relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
                m.opera = AlgebraicAgents.Opera(m.uuid => m)

                m
            end
        end
    )
end

macro aagent(base_type, type)
    define_agent(base_type, AbstractAlgebraicAgent, type, __module__, quote
            function $(type.args[2])(name::Vararg{<:AbstractString})
                m = new()
                !isempty(name) && (m.name = first(name)); m.uuid = AlgebraicAgents.uuid4()
                m.parent = nothing; m.inners = Dict{String, AbstractAlgebraicAgent}()
                m.relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
                m.opera = AlgebraicAgents.Opera(m.uuid => m)

                m
            end
        end
    )
end

macro aagent(base_type, super_type, type)
    define_agent(base_type, super_type, type, __module__, quote
            function $(type.args[2])(name::Vararg{<:AbstractString})
                m = new()
                !isempty(name) && (m.name = first(name)); m.uuid = AlgebraicAgents.uuid4()
                m.parent = nothing; m.inners = Dict{String, AbstractAlgebraicAgent}()
                m.relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
                m.opera = AlgebraicAgents.Opera(m.uuid => m)

                m
            end
        end
    )
end