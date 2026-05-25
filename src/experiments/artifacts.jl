"""
    write_result_artifact(result, path)

Write a portable Markdown experiment artifact containing the spec, metrics,
parameters, notes, and research decision.
"""
function write_result_artifact(result::ExperimentResult, path::AbstractString)
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, "# ", result.spec.title)
        println(io)
        println(io, "- Experiment: `", result.spec.id, "`")
        println(io, "- Dataset: `", result.spec.dataset.id, "`")
        println(io, "- Workload: `", result.spec.workload.id, "`")
        println(io, "- Idea: `", result.spec.idea, "`")
        println(io)
        println(io, "## Metrics")
        for metric in result.spec.metrics
            println(io, "- `", metric.name, "`: ", result.metrics[metric.name])
        end
        if !isempty(result.spec.parameters)
            println(io)
            println(io, "## Parameters")
            for key in sort(collect(keys(result.spec.parameters)))
                println(io, "- `", key, "`: ", result.spec.parameters[key])
            end
        end
        if !isempty(result.notes)
            println(io)
            println(io, "## Notes")
            for note in result.notes
                println(io, "- ", note)
            end
        end
        decision = decide_research_promotion(result)
        println(io)
        println(io, "## Research Decision")
        println(io, "- Status: `", decision.status, "`")
    end
    return path
end

"""
    write_experiment_manifest(result, path; validation_reports = ValidationReport[], benchmark_report = nothing, baseline = nothing, required_delta = 0)

Write a machine-readable TOML sidecar for downstream notebook and production
evidence synchronization.

Throws `ArgumentError` when the baseline or benchmark report belongs to a
different experiment spec.
"""
function write_experiment_manifest(
    result::ExperimentResult,
    path::AbstractString;
    validation_reports::Vector{ValidationReport} = ValidationReport[],
    benchmark_report::Union{Nothing,BenchmarkReport} = nothing,
    baseline::Union{Nothing,ExperimentResult} = nothing,
    required_delta::Real = 0,
)
    isnothing(benchmark_report) || benchmark_report.spec === result.spec ||
        throw(ArgumentError("benchmark report must use the result experiment spec"))
    isnothing(baseline) || baseline.spec === result.spec ||
        throw(ArgumentError("baseline must use the result experiment spec"))

    manifest = experiment_manifest(
        result;
        validation_reports,
        benchmark_report,
        baseline,
        required_delta,
    )
    mkpath(dirname(path))
    open(path, "w") do io
        TOML.print(io, manifest)
    end
    return path
end

"""
    read_experiment_manifest(path)

Read an experiment manifest previously written by `write_experiment_manifest`.

Throws `ErrorException` when the manifest file is missing.
"""
function read_experiment_manifest(path::AbstractString)
    isfile(path) || error("experiment manifest does not exist: $path")
    return TOML.parsefile(path)
end

function experiment_manifest(
    result::ExperimentResult;
    validation_reports::Vector{ValidationReport},
    benchmark_report::Union{Nothing,BenchmarkReport},
    baseline::Union{Nothing,ExperimentResult},
    required_delta::Real,
)
    decision = decide_research_promotion(result; baseline, required_delta)
    manifest = Dict{String,Any}(
        "schema" => "scienceresearch.experiment_manifest.v1",
        "experiment" => Dict{String,Any}(
            "id" => result.spec.id,
            "title" => result.spec.title,
            "idea" => result.spec.idea,
        ),
        "dataset" => Dict{String,Any}(
            "id" => result.spec.dataset.id,
            "description" => result.spec.dataset.description,
            "source" => result.spec.dataset.source,
        ),
        "workload" => Dict{String,Any}(
            "id" => result.spec.workload.id,
            "description" => result.spec.workload.description,
            "scale" => result.spec.workload.scale,
            "budget" => result.spec.workload.budget,
        ),
        "parameters" => result.spec.parameters,
        "metrics" => metric_manifest_rows(result),
        "result" => Dict{String,Any}("metrics" => result.metrics, "notes" => result.notes),
        "validation" => validation_manifest_rows(validation_reports),
        "decision" => Dict{String,Any}(
            "status" => string(decision.status),
            "reasons" => decision.reasons,
            "metric_deltas" => decision.metric_deltas,
        ),
    )
    isnothing(result.spec.dataset.row_count) ||
        (manifest["dataset"]["row_count"] = result.spec.dataset.row_count)
    isnothing(result.spec.dataset.byte_size) ||
        (manifest["dataset"]["byte_size"] = result.spec.dataset.byte_size)
    if !isnothing(benchmark_report)
        manifest["benchmark"] = benchmark_manifest(benchmark_report)
    end
    return manifest
end

function metric_manifest_rows(result::ExperimentResult)
    [
        metric_manifest_row(metric, result.metrics[metric.name]) for metric in result.spec.metrics
    ]
end

function metric_manifest_row(metric::MetricSpec, value::Float64)
    row = Dict{String,Any}(
            "name" => metric.name,
            "direction" => string(metric.direction),
            "value" => value,
        )
    isnothing(metric.threshold) || (row["threshold"] = metric.threshold)
    return row
end

function validation_manifest_rows(validation_reports::Vector{ValidationReport})
    [
        Dict{String,Any}(
            "subject_kind" => string(report.subject_kind),
            "subject_id" => report.subject_id,
            "passed" => validation_passed(report),
            "checks" => [
                Dict{String,Any}(
                    "name" => check.name,
                    "passed" => check.passed,
                    "detail" => check.detail,
                ) for check in report.checks
            ],
        ) for report in validation_reports
    ]
end

function benchmark_manifest(report::BenchmarkReport)
    return Dict{String,Any}(
        "summary" => benchmark_summary(report),
        "samples" => [
            Dict{String,Any}(
                "iteration" => sample.iteration,
                "elapsed_ms" => sample.elapsed_ms,
                "metrics" => sample.metrics,
            ) for sample in report.samples
        ],
    )
end
