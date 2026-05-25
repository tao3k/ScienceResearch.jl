using ScienceResearch

@testset "config" begin
    config = parse_notebook_html_build_config(
        [
            "--package-root",
            ".",
            "--notebook-dir",
            "notebooks",
            "--output-dir",
            "build/html",
            "--project-title",
            "Research",
            "--max-concurrent-runs",
            "2",
            "--sequential",
            "--include-backups",
            "--no-embedded-highlight-assets",
            "--dry-run",
        ];
        package_root = pwd(),
    )
    @test config.project_title == "Research"
    @test config.max_concurrent_runs == 2
    @test !config.use_distributed
    @test config.include_backups
    @test config.dry_run
    @test !config.embed_highlight_assets
    @test_throws ErrorException parse_notebook_html_build_config(["--unknown"])
    @test_throws ErrorException parse_notebook_html_build_config(["--max-concurrent-runs", "0"])
end
