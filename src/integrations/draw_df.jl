"""
    @draw_df T field
A macro to define `_draw(T)` such that it will plot a DataFrame stored under `field`.

The implementation calls [`plot_df`](@ref), whose method is provided by the
extension that ships with `DataFrames` and `Plots` (loaded automatically once
both are available).

# Examples
```julia
@draw_df my_type log # will plot `log` property (a DataFrame) of `my_type`'s instance
```
"""
macro draw_df(T, field)
    return quote
        function AlgebraicAgents._draw(a::$T)
            df = getproperty(a, $(QuoteNode(field)))
            return AlgebraicAgents.plot_df(df)
        end
    end |> esc
end
