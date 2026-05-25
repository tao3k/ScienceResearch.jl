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

        artifact_dir = joinpath(dir, "artifacts")
        mkpath(artifact_dir)
        write(
            joinpath(artifact_dir, "candidate.toml"),
            "schema = \"scienceresearch.experiment_manifest.v1\"\n",
        )
        evidence_notebook = VALID_NOTEBOOK * "\n# scienceresearch-artifact: candidate.toml\n"
        @test isempty(validate_notebook_evidence(evidence_notebook, artifact_dir))
        @test validate_notebook_evidence(VALID_NOTEBOOK, artifact_dir) ==
              ["notebook does not reference experiment evidence"]
        missing_issues = validate_notebook_evidence(
            VALID_NOTEBOOK * "\n# scienceresearch-artifact: missing.toml\n",
            artifact_dir,
        )
        @test "artifact reference does not exist: missing.toml" in missing_issues
        escaped_issues = validate_notebook_evidence(
            VALID_NOTEBOOK * "\n# scienceresearch-artifact: ../candidate.toml\n",
            artifact_dir,
        )
        @test !isempty(escaped_issues)
        @test_throws ErrorException validate_notebook_evidence(evidence_notebook, joinpath(dir, "missing-artifacts"))
    end
end
