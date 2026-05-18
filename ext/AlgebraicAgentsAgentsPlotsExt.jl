module AlgebraicAgentsAgentsPlotsExt

using AlgebraicAgents
import Plots

# plot reduction for `ABMAgent`; relies on `plot_df` provided by the
# `AlgebraicAgentsDataFramesPlotsExt` extension (loaded automatically when
# `Plots` and `DataFrames` are both available).
function AlgebraicAgents._draw(a::AlgebraicAgents.ABMAgent, args...; df_only = true, kwargs...)
    return if df_only
        plot_model = isempty(a.df_model) ? nothing : AlgebraicAgents.plot_df(a.df_model)
        plot_agents = isempty(a.df_agents) ? nothing : AlgebraicAgents.plot_df(a.df_agents)
        isnothing(plot_model) ? plot_agents :
            isnothing(plot_agents) ? plot_model : Plots.plot([plot_agents, plot_model])
    end
end

end # module
