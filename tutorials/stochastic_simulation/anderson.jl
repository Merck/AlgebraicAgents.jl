using AlgebraicAgents, Distributions, DataFrames

# using Infiltrator

β = 0.05*10.0
γ = 0.25

# reaction system
@aagent struct ReactionSystem{T<:Real,S<:Number}
    t::T
    Δ::T
    X::Vector{S}
    X0::Vector{S}
    # simulation trajectory
    df_output::DataFrame
end

function make_reactionsystem(name::T, X0::Vector{S}) where {T,S}
    df_output = DataFrame(time=Float64[])
    for i in eachindex(X0)
        insertcols!(df_output, Symbol("X"*string(i))=>S[])
    end
    rs = ReactionSystem{Float64,S}(name, 0.0, 0.0, X0, X0, df_output)
    entangle!(rs, FreeAgent("clocks"))
    return rs
end

function AlgebraicAgents._step!(a::ReactionSystem)
    # track hist
    push!(a.df_output, [a.t, a.X...])
end

# function _reinit!(a::ReactionSystem{T,S}) where {T,S}
#     a.t = zero(T)
#     a.Δ = zero(T)
#     a.X = a.X0
# end

# function AlgebraicAgents._projected_to(a::ReactionSystem{T,S}) where {T,S}
#     a.t
# end

# AlgebraicAgents._projected_to(a::ReactionSystem) = nothing
# AlgebraicAgents._projected_to(a::ReactionSystem) = a.t
function AlgebraicAgents._projected_to(a::ReactionSystem)
    ret = nothing
    foreach(values(inners(a))) do a
        AlgebraicAgents.@ret ret projected_to(a; isroot = false)
    end
    return ret
end



# clock process
@aagent struct Clock{N<:Real,Fn<:Function,S<:Number}

    P::N # next internal firing time of Poisson process (Pk > Tk)
    T::N # internal time of Poisson process
    Δt::N # absolute time interval before next firing
    τ::N # next absolute time to fire
    a::N # current intensity
    intensity::Fn # intensity function
    ν::Vector{S} # state change vector

end

function add_clock!(rs, name::T, intensity::U, ν::Vector{S}) where {T,U,S}
    c = Clock{Float64,U,S}(name, 0.0, 0.0, 0.0, 0.0, 0.0, intensity, ν)

    # calculate intensity
    c.a = c.intensity(rs.X)

    # draw internal jump times
    c.P = rand(Exponential())

    # update time of first firing (i dont like this)
    c.Δt = (c.P - c.T) / c.a
    c.τ += c.Δt

    # entangle the clock
    entangle!(inners(rs)["clocks"], c)

    # add the control (update integrated intensity)
    add_control!(rs, () -> control_clock(c), "control " * name)
end

# clock interface
function AlgebraicAgents._projected_to(c::Clock)
    c.τ
end

function AlgebraicAgents._step!(c::Clock)
    topmost(c).Δ = c.τ - topmost(c).t
    topmost(c).t = c.τ # t += Δ
    topmost(c).X += c.ν # update state
    c.P += rand(Exponential()) # Pμ += Exp(1)
end

# now part of control. i dont like that.
# # prestep to update time to next firing
# function AlgebraicAgents._prestep!(c::Clock, _)
#     c.Δt = (c.P - c.T) / c.a
#     c.τ += c.Δt
# end

# function _reinit!(a::Clock{N,Fn}) where {N,Fn}
#     # initialize
#     a.Pk = zero(N)
#     a.Tk = zero(N)
#     a.delta_t = zero(N)
#     a.ak = zero(N)

#     # calculate intensity
#     reactionsys = topmost(a)
#     a.ak = a.intensity(reactionsys.X, 0.0)

#     # draw internal jump times
#     a.Pk = rand(Exponential())
# end


# control interactions to update state
# function control_clock(c::Clock)
#     c.T += c.a * topmost(c).Δ # Tk += ak*Δ
#     c.a = c.intensity(topmost(c).X) # update intensity
# end

function control_clock(c::Clock)
    c.T += c.a * topmost(c).Δ # Tk += ak*Δ
    c.a = c.intensity(topmost(c).X) # update intensity
    # update time of next firing
    c.Δt = (c.P - c.T) / c.a
    c.τ += c.Δt
end


# add some clocks
rs = make_reactionsystem("SIR", [990, 10, 0])
add_clock!(rs, "infection", (x) -> β*x[2]/sum(x)*x[1], [-1,1,0])
add_clock!(rs, "recovery", (x) -> γ*x[2], [0,-1,1])

using Debugger
using JuliaInterpreter

# breakpoint(step!)
breakpoint(AlgebraicAgents.step!)
breakpoint(AlgebraicAgents._step!)
# breakpoint(AlgebraicAgents._prestep!)
# breakpoint(control_clock)

Debugger.@run step!(rs)

step!(rs)
