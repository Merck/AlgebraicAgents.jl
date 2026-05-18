module AlgebraicAgentsDataFramesPlotsExt

using AlgebraicAgents
import DataFrames
import Plots

"""
    plot_df(df, t_ix=1)
Convert DataFrame to a plot, taking `t_ix` as the time column.

Requires `DataFrames` and `Plots` to be available.
"""
function AlgebraicAgents.plot_df(df::DataFrames.DataFrame, t_ix::Int = 1)
    data = Matrix(df)
    t = @view data[:, t_ix]
    data_ = @view data[:, setdiff(1:size(data, 2), (t_ix,))]
    colnames = reshape(DataFrames.names(df)[setdiff(1:size(data, 2), (t_ix,))], 1, :)

    return Plots.plot(t, data_, labels = colnames, xlabel = "t")
end

end # module
