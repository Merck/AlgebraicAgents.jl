module AlgebraicAgentsSciMLPlotsExt

using AlgebraicAgents
import Plots

# plot reduction for `DiffEqAgent`
function AlgebraicAgents._draw(a::AlgebraicAgents.DiffEqAgent, args...; kwargs...)
    return Plots.plot(a.integrator.sol, args...; kwargs...)
end

end # module
