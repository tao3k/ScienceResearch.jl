"""
    BenchmarkSample

Record one benchmark iteration with wall-clock latency and the measured
experiment metrics.
"""
struct BenchmarkSample
    iteration::Int
    elapsed_ms::Float64
    metrics::Dict{String,Float64}
end

"""
    BenchmarkReport

Collect benchmark samples and the final experiment result for a benchmarked
algorithm candidate.
"""
struct BenchmarkReport
    spec::ExperimentSpec
    samples::Vector{BenchmarkSample}
    result::ExperimentResult
end

"""
    benchmark_experiment(spec, runner; samples = 3)

Run an experiment multiple times, capture elapsed wall time, and return a
`BenchmarkReport` with the final result.

Throws `ArgumentError` when `samples` is not positive or any run returns an
invalid experiment result.
"""
function benchmark_experiment(spec::ExperimentSpec, runner; samples::Integer = 3)
    samples > 0 || throw(ArgumentError("benchmark samples must be positive"))
    benchmark_samples = BenchmarkSample[]
    final_result = nothing
    for iteration in 1:samples
        started = time_ns()
        result = run_experiment(spec, runner)
        elapsed_ms = (time_ns() - started) / 1_000_000
        push!(benchmark_samples, BenchmarkSample(iteration, elapsed_ms, copy(result.metrics)))
        final_result = result
    end
    return BenchmarkReport(spec, benchmark_samples, final_result::ExperimentResult)
end

function benchmark_experiment(runner, spec::ExperimentSpec; samples::Integer = 3)
    return benchmark_experiment(spec, runner; samples)
end

"""
    benchmark_summary(report)

Return benchmark latency aggregates and final metric values.
"""
function benchmark_summary(report::BenchmarkReport)
    elapsed = [sample.elapsed_ms for sample in report.samples]
    summary = Dict{String,Float64}(
        "samples" => Float64(length(report.samples)),
        "elapsed_ms_min" => minimum(elapsed),
        "elapsed_ms_mean" => sum(elapsed) / length(elapsed),
        "elapsed_ms_max" => maximum(elapsed),
    )
    for (name, value) in report.result.metrics
        summary["metric.$name"] = value
    end
    return summary
end
