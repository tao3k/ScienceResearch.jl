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
    @test threshold_report(candidate) == Dict(
        "quality_score" => true,
        "latency_ms" => true,
        "memory_mb" => true,
    )
    data_report = validate_dataset(dataset, [
        active_dataset -> ValidationCheck(;
            name = "row-count-present",
            passed = !isnothing(active_dataset.row_count),
            detail = "fixture declares deterministic scale",
        ),
    ])
    @test data_report.subject_kind == :dataset
    @test validation_passed(data_report)

    algorithm_report = validate_algorithm(spec, [
        active_spec -> ValidationCheck(;
            name = "has-budget",
            passed = haskey(active_spec.workload.budget, "latency_ms"),
        ),
    ])
    @test algorithm_report.subject_kind == :algorithm
    @test validation_passed(algorithm_report)

    benchmark = benchmark_experiment(spec, samples = 2) do active_spec
        ExperimentResult(
            active_spec;
            metrics = Dict("quality_score" => 0.80, "latency_ms" => 7.0, "memory_mb" => 90.0),
        )
    end
    benchmark_stats = benchmark_summary(benchmark)
    @test length(benchmark.samples) == 2
    @test benchmark.result.spec === spec
    @test benchmark_stats["samples"] == 2.0
    @test benchmark_stats["metric.quality_score"] == 0.80
    @test benchmark_stats["elapsed_ms_max"] >= benchmark_stats["elapsed_ms_min"]

    decision = decide_research_promotion(candidate; baseline, required_delta = 0.0)
    @test decision.status == :promote
    @test isempty(decision.reasons)
    @test decision.metric_deltas["quality_score"] == 0.25

    mktempdir() do dir
        path = write_result_artifact(candidate, joinpath(dir, "result.md"))
        text = read(path, String)
        @test occursin("# Algorithm Feasibility", text)
        @test occursin("`quality_score`: 0.75", text)
        @test occursin("`vectorized candidate scoring`", text)
        @test occursin("Status: `promote`", text)
        @test occursin("candidate improves quality and latency", text)

        manifest_path = write_experiment_manifest(
            candidate,
            joinpath(dir, "result.toml");
            validation_reports = [data_report, algorithm_report],
            benchmark_report = benchmark,
            baseline,
        )
        manifest = read_experiment_manifest(manifest_path)
        @test manifest["schema"] == "scienceresearch.experiment_manifest.v1"
        @test manifest["experiment"]["id"] == "algorithm-feasibility"
        @test manifest["dataset"]["row_count"] == 10_000
        @test manifest["decision"]["status"] == "promote"
        @test length(manifest["validation"]) == 2
        @test manifest["benchmark"]["summary"]["samples"] == 2.0
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
    @test_throws ArgumentError ValidationCheck(; name = "", passed = true)
    @test_throws ArgumentError ValidationReport(;
        subject_kind = :dataset,
        subject_id = "",
        checks = [ValidationCheck(; name = "ok", passed = true)],
    )
    @test_throws ArgumentError run_experiment(spec, _ -> "not a result")
    @test_throws ArgumentError validate_dataset(dataset, Function[])
    @test_throws ArgumentError validate_dataset(dataset, [_ -> "not a check"])
    @test_throws ArgumentError benchmark_experiment(spec, _ -> candidate; samples = 0)
    @test_throws ArgumentError compare_baseline(candidate, baseline; metric = "missing")
    other_spec = ExperimentSpec(;
        id = "other-candidate",
        title = "Other Candidate",
        dataset,
        workload,
        idea = "different candidate",
        metrics = [quality, latency, memory],
    )
    other_result = ExperimentResult(
        other_spec;
        metrics = Dict("quality_score" => 0.5, "latency_ms" => 10.0, "memory_mb" => 100.0),
    )
    @test_throws ArgumentError write_experiment_manifest(candidate, "bad.toml"; baseline = other_result)
    @test_throws ErrorException read_experiment_manifest("missing.toml")
    @test_throws ArgumentError decide_research_promotion(candidate; required_delta = -1)

    weak_candidate = ExperimentResult(
        spec;
        metrics = Dict("quality_score" => 0.40, "latency_ms" => 120.0, "memory_mb" => 300.0),
    )
    weak_decision = decide_research_promotion(weak_candidate; baseline)
    @test weak_decision.status == :needs_more_evidence
    @test "threshold failed: memory_mb" in weak_decision.reasons
    @test "baseline delta failed: quality_score" in weak_decision.reasons
end
