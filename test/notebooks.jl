using ScienceResearch

const VALID_NOTEBOOK = """
### A Pluto.jl notebook ###
# v0.20.24

# ╔═╡ 11111111-1111-4111-8111-111111111111
md\"\"\"
# Sample
\"\"\"

# ╔═╡ 22222222-2222-4222-8222-222222222222
function sample_value()
    1
end

# ╔═╡ Cell order:
# ╟─11111111-1111-4111-8111-111111111111
# ╠═22222222-2222-4222-8222-222222222222
"""

const INVALID_NOTEBOOK = """
### A Pluto.jl notebook ###
# v0.20.24

# ╔═╡ 11111111-1111-4111-8111-111111111111
function one()
    1
end

function two()
    2
end

# ╔═╡ Cell order:
# ╠═11111111-1111-4111-8111-111111111111
"""

@testset "notebooks" begin
    mktempdir() do dir
        notebook_dir = joinpath(dir, "notebooks")
        mkpath(notebook_dir)
        write(joinpath(notebook_dir, "sample_notebook.jl"), VALID_NOTEBOOK)
        write(joinpath(notebook_dir, "sample_notebook backup.jl"), VALID_NOTEBOOK)
        write(joinpath(notebook_dir, "notes.jl"), "not a notebook")

        @test is_pluto_notebook(joinpath(notebook_dir, "sample_notebook.jl"))
        @test discover_pluto_notebooks(notebook_dir) == ["sample_notebook.jl"]
        @test length(discover_pluto_notebooks(notebook_dir; include_backups = true)) == 2
        @test notebook_title("sample_notebook.jl") == "sample notebook"
        @test isempty(validate_pluto_notebook(VALID_NOTEBOOK))
        @test !isempty(validate_pluto_notebook(INVALID_NOTEBOOK))
        @test isempty(validate_pluto_notebook_file(joinpath(notebook_dir, "sample_notebook.jl")))
        @test_throws ErrorException discover_pluto_notebooks(joinpath(dir, "missing"))
    end
end
