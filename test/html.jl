using ScienceResearch

@testset "html shell" begin
    html = notebook_index_html(
        ["sample_notebook.jl"];
        project_title = "Sample notebooks",
        embed_highlight_assets = false,
    )
    @test occursin("Sample notebooks", html)
    @test occursin("MathJax", html)
    @test occursin("highlight.min.js", html)
    @test occursin("languages/julia.min.js", html)
    @test occursin("languages/markdown.min.js", html)
    @test occursin("languages/latex.min.js", html)
    @test occursin("overflow-x: auto", html)

    mktempdir() do dir
        index_path = write_notebook_index(
            dir,
            ["sample_notebook.jl"];
            project_title = "Sample notebooks",
            embed_highlight_assets = false,
        )
        @test isfile(index_path)
        @test occursin("sample_notebook.html", read(index_path, String))
    end
end
