import .DataFrames, .Plots

"""
    plot_df(df, t_ix=1)
Convert DataFrame to a plot, taking `t_ix` as the time column.

Requires `DataFrames` and `Plots` to be available.
"""
function plot_df(df::DataFrames.DataFrame, t_ix::Int = 1)
    data = Matrix(df)
    t_ix = t_ix
    t = @view data[:, t_ix]
    data_ = @view data[:, setdiff(1:size(data, 2), (t_ix,))]
    colnames = reshape(DataFrames.names(df)[setdiff(1:size(data, 2), (t_ix,))], 1, :)

    Plots.plot(t, data_, labels = colnames, xlabel = "t")
end

"""
    @draw_df T field
A macro to define `_draw(T)` such that it will plot a DataFrame stored under `field`.

Requires `DataFrames` and `Plots` to be available.

# Examples
```julia
@draw_df my_type log # will plot `log` property (a DataFrame) of `my_type`'s instance
```
"""
macro draw_df(T, field)
    quote
        function AlgebraicAgents._draw(a::$T)
            df = getproperty(a, $(QuoteNode(field)))
            AlgebraicAgents.plot_df(df)
        end
    end |> esc
end
