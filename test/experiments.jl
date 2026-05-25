using ScienceResearch

@testset "experiments" begin
    dataset = DatasetSpec(;
        id = "synthetic-table",
        description = "Synthetic tabular fixture",
        source = "memory",
        row_count = 10_000,
        byte_size = 1_048_576,
    )
    workload = WorkloadSpec(;
        id = "batch-feasibility",
        description = "Batch algorithm feasibility workload",
        scale = Dict("items" => 10_000, "features" => 32),
        budget = Dict("latency_ms" => 100.0, "memory_mb" => 256.0),
    )
    quality = MetricSpec(; name = "quality_score")
    latency = MetricSpec(; name = "latency_ms", direction = :lower_is_better)
    memory = MetricSpec(; name = "memory_mb", direction = :lower_is_better, threshold = 256)
    spec = ExperimentSpec(;
        id = "algorithm-feasibility",
        title = "Algorithm Feasibility",
        dataset,
        workload,
        idea = "vectorized candidate scoring",
        metrics = [quality, latency, memory],
        parameters = Dict("batch_size" => "128"),
    )

    baseline = ExperimentResult(
        spec;
        metrics = Dict("quality_score" => 0.5, "latency_ms" => 12.0, "memory_mb" => 100.0),
    )
    candidate = run_experiment(spec) do active_spec
        ExperimentResult(
            active_spec;
            metrics = Dict("quality_score" => 0.75, "latency_ms" => 8.0, "memory_mb" => 96.0),
            notes = ["candidate improves quality and latency"],
        )
    end

    @test candidate.spec === spec
    @test candidate.spec.dataset.row_count == 10_000
    @test candidate.spec.workload.scale["features"] == 32.0
    @test compare_baseline(candidate, baseline; metric = "quality_score") == 0.25
    @test compare_baseline(candidate, baseline; metric = "latency_ms") == 4.0

    mktempdir() do dir
        path = write_result_artifact(candidate, joinpath(dir, "result.md"))
        text = read(path, String)
        @test occursin("# Algorithm Feasibility", text)
        @test occursin("`quality_score`: 0.75", text)
        @test occursin("`vectorized candidate scoring`", text)
        @test occursin("candidate improves quality and latency", text)
    end

    @test_throws ArgumentError DatasetSpec(; id = "", description = "", source = "")
    @test_throws ArgumentError DatasetSpec(;
        id = "bad",
        description = "",
        source = "",
        row_count = -1,
    )
    @test_throws ArgumentError WorkloadSpec(; id = "", description = "")
    @test_throws ArgumentError WorkloadSpec(;
        id = "bad",
        description = "",
        budget = Dict("latency_ms" => -1),
    )
    @test_throws ArgumentError MetricSpec(; name = "bad", direction = :sideways)
    @test_throws ArgumentError ExperimentSpec(;
        id = "",
        title = "Bad",
        dataset,
        workload,
        idea = "candidate",
        metrics = [quality],
    )
    @test_throws ArgumentError ExperimentResult(
        spec;
        metrics = Dict("quality_score" => 0.1),
    )
    @test_throws ArgumentError run_experiment(spec, _ -> "not a result")
    @test_throws ArgumentError compare_baseline(candidate, baseline; metric = "missing")
end
