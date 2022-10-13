# adapted content from https://github.com/JuliaDynamics/Agents.jl/blob/83129042f01673f832e4a32de53b93ecd6af80ab/src/core/agents.jl

"""
    @aagent agent_name begin
        extra_fields...
    end

Create a custom algebraic agent type, and include fields expected by default interface methods (see [`FreeAgent`](@ref)).

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
macro aagent(new_name, extra_fields)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912

    # We start with a quote. All macros return a quote to be evaluated
    base_type = FreeAgent
    extra_fields = MacroTools.striplines(extra_fields)
    quote
        let
            # Here we collect the field names and types from the base type
            # Because the base type already exists, we escape the symbols to obtain it
            base_fieldnames = fieldnames($(esc(base_type)))
            base_fieldtypes = [t for t in getproperty($(esc(base_type)), :types)]
            base_fields = [:($f::$T) for (f, T) in zip(base_fieldnames, base_fieldtypes)]
            # Then, we prime the additional name and fields into QuoteNodes
            # We have to do this to be able to interpolate them into an inner quote.
            name = $(QuoteNode(new_name))
            additional_fields = $(QuoteNode(extra_fields.args))
            additional_fieldnames = [Meta.isexpr(f, :(::)) ? f.args[1] : f for f in $(QuoteNode(extra_fields.args))]

            # Now we start an inner quote. This is because our macro needs to call `eval`
            # However, this should never happen inside the main body of a macro
            # There are several reasons for that, see the cited discussion at the top

            expr = quote
                mutable struct $name <: AbstractAlgebraicAgent
                    $(base_fields...)
                    $(additional_fields...)

                    function $(name)(name::AbstractString)
                        m = new()
                        m.name = name; m.uuid = AlgebraicAgents.uuid4()
                        m.parent = nothing; m.inners = Dict{String, AbstractAlgebraicAgent}()
                        m.relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
                        m.opera = AlgebraicAgents.Opera(m.uuid => m)

                        m
                    end
                end
            end
            # @show expr # uncomment this to see that the final expression looks as desired
            # It is important to evaluate the macro in the module that it was called at
            Core.eval($(__module__), expr)
        end
    end
end

"""
    @aagent agent_name supertype begin
        extra_fields...
    end

Create a custom algebraic agent type, and include fields expected by default interface methods (see [`FreeAgent`](@ref)).

# Example 
```julia
@aagent SmallMolecule Molecule begin
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
macro aagent(new_name, super_type, extra_fields)
    # This macro was generated with the guidance of @rdeits on Discourse:
    # https://discourse.julialang.org/t/
    # metaprogramming-obtain-actual-type-from-symbol-for-field-inheritance/84912

    # We start with a quote. All macros return a quote to be evaluated
    base_type = FreeAgent
    extra_fields = MacroTools.striplines(extra_fields)
    quote
        let
            # Here we collect the field names and types from the base type
            # Because the base type already exists, we escape the symbols to obtain it
            base_fieldnames = fieldnames($(esc(base_type)))
            base_fieldtypes = [t for t in getproperty($(esc(base_type)), :types)]
            base_fields = [:($f::$T) for (f, T) in zip(base_fieldnames, base_fieldtypes)]
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

                    function $(name)(name::AbstractString)
                        m = new()
                        m.name = name; m.uuid = AlgebraicAgents.uuid4()
                        m.parent = nothing; m.inners = Dict{String, AbstractAlgebraicAgent}()
                        m.relpathrefs = Dict{AbstractString, AlgebraicAgents.UUID}()
                        m.opera = AlgebraicAgents.Opera(m.uuid => m)

                        m
                    end
                end
            end
            # @show expr # uncomment this to see that the final expression looks as desired
            # It is important to evaluate the macro in the module that it was called at
            Core.eval($(__module__), expr)
        end
    end
end