function __init__()
    # SciMLIntegration
    @require DifferentialEquations="0c46a032-eb83-5123-abaf-570d42b7fbaa" include("SciMLIntegration/core.jl")

    ## plotting
    @require DifferentialEquations="0c46a032-eb83-5123-abaf-570d42b7fbaa" begin
        @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" include("SciMLIntegration/plots.jl")
    end

    # AgentsIntegration
    @require Agents="46ada45e-f475-11e8-01d0-f70cc89e6671" include("AgentsIntegration/core.jl")

    ## plotting
    @require Agents="46ada45e-f475-11e8-01d0-f70cc89e6671" begin
        @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" include("AgentsIntegration/plots.jl")
    end

    # AlgebraicDynamicsIntegration
    @require AlgebraicDynamics="5fd6ff03-a254-427e-8840-ba658f502e32" include("AlgebraicDynamicsIntegration/core.jl")

    ## SciML transforms
    @require AlgebraicDynamics="5fd6ff03-a254-427e-8840-ba658f502e32" begin
        @require DifferentialEquations="0c46a032-eb83-5123-abaf-570d42b7fbaa" include("AlgebraicDynamicsIntegration/sciml_transform.jl")
    end

    # DataFrame log out-of-the-box plots
    @require DataFrames="a93c6f00-e57d-5684-b7b6-d8193f3e46c0" begin
        @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" include("utils_plots.jl")
    end
end
