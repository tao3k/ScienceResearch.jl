using Test
using ScienceResearch

@testset "ScienceResearch" begin
    include("notebooks.jl")
    include("html.jl")
    include("config.jl")
    include("experiments.jl")
    @test_throws ErrorException parse_notebook_html_build_config(["--unknown"])
    @test_throws ErrorException discover_pluto_notebooks(joinpath(@__DIR__, "missing"))
    @test_throws ArgumentError MetricSpec(; name = "latency", direction = :sideways)
    include("harness.jl")
end
