import .Plots

# plot reduction
function _draw(a::DiffEqAgent, args...; kwargs...)
    Plots.plot(a.integrator.sol, args...; kwargs...)
end
