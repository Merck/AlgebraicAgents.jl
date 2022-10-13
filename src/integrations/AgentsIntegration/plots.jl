import .Plots

function plot_df(df::DataFrames.DataFrame, t_ix=1)
    data = Matrix(df)
    t = @view data[:, t_ix]; data_ = @view data[:, setdiff(1:size(data, 2), (t_ix,))]
    colnames = reshape(DataFrames.names(df)[setdiff(1:size(data, 2), (t_ix,))], 1, :)

    Plots.plot(t, data_, labels=colnames, xlabel="t")
end

# plot reduction
function _draw(a::ABMAgent, args...; df_only=true, kwargs...)
    if df_only
        plot_model = isempty(a.df_model) ? nothing : plot_df(a.df_model)
        plot_agents = isempty(a.df_agents) ? nothing : plot_df(a.df_agents)
        isnothing(plot_model) ? plot_agents : 
            isnothing(plot_agents) ? plot_model : Plots.plot([plot_agents, plot_model])
    end
end