"""
    BenchmarkSample

Record one benchmark iteration with wall-clock latency and the measured
experiment metrics.
"""
struct BenchmarkSample
    iteration::Int
    elapsed_ms::Float64
    allocated_bytes::Float64
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
    warmups::Int
    regression_threshold_ms::Union{Nothing,Float64}
    warnings::Vector{String}
end

"""
    benchmark_experiment(spec, runner; samples = 3, warmups = 0, regression_threshold_ms = nothing, noise_ratio_threshold = 0.25)

Run warmup iterations followed by measured iterations, capture elapsed wall
time and allocation observations, and return a `BenchmarkReport` with the final
result.

Throws `ArgumentError` when `samples` is not positive, `warmups` is negative,
threshold arguments are invalid, or any run returns an invalid experiment
result.
"""
function benchmark_experiment(
    spec::ExperimentSpec,
    runner;
    samples::Integer = 3,
    warmups::Integer = 0,
    regression_threshold_ms::Union{Nothing,Real} = nothing,
    noise_ratio_threshold::Real = 0.25,
)
    samples > 0 || throw(ArgumentError("benchmark samples must be positive"))
    warmups >= 0 || throw(ArgumentError("benchmark warmups must be non-negative"))
    noise_ratio_threshold >= 0 ||
        throw(ArgumentError("benchmark noise ratio threshold must be non-negative"))
    threshold = normalized_optional_positive_float(regression_threshold_ms, "regression_threshold_ms")
    for _ in 1:warmups
        run_experiment(spec, runner)
    end

    benchmark_samples = BenchmarkSample[]
    final_result = nothing
    for iteration in 1:samples
        started = time_ns()
        result = nothing
        allocated_bytes = @allocated begin
            result = run_experiment(spec, runner)
        end
        elapsed_ms = (time_ns() - started) / 1_000_000
        push!(
            benchmark_samples,
            BenchmarkSample(iteration, elapsed_ms, Float64(allocated_bytes), copy(result.metrics)),
        )
        final_result = result
    end
    report = BenchmarkReport(
        spec,
        benchmark_samples,
        final_result::ExperimentResult,
        Int(warmups),
        threshold,
        String[],
    )
    append!(report.warnings, benchmark_warnings(report; noise_ratio_threshold))
    return report
end

function benchmark_experiment(
    runner,
    spec::ExperimentSpec;
    samples::Integer = 3,
    warmups::Integer = 0,
    regression_threshold_ms::Union{Nothing,Real} = nothing,
    noise_ratio_threshold::Real = 0.25,
)
    return benchmark_experiment(
        spec,
        runner;
        samples,
        warmups,
        regression_threshold_ms,
        noise_ratio_threshold,
    )
end

"""
    benchmark_summary(report)

Return benchmark latency aggregates and final metric values.
"""
function benchmark_summary(report::BenchmarkReport)
    elapsed = [sample.elapsed_ms for sample in report.samples]
    allocated = [sample.allocated_bytes for sample in report.samples]
    summary = Dict{String,Float64}(
        "samples" => Float64(length(report.samples)),
        "warmups" => Float64(report.warmups),
        "elapsed_ms_min" => minimum(elapsed),
        "elapsed_ms_p50" => percentile(elapsed, 0.50),
        "elapsed_ms_p95" => percentile(elapsed, 0.95),
        "elapsed_ms_mean" => sum(elapsed) / length(elapsed),
        "elapsed_ms_max" => maximum(elapsed),
        "allocated_bytes_min" => minimum(allocated),
        "allocated_bytes_mean" => sum(allocated) / length(allocated),
        "allocated_bytes_max" => maximum(allocated),
        "warning_count" => Float64(length(report.warnings)),
    )
    isnothing(report.regression_threshold_ms) ||
        (summary["regression_threshold_ms"] = report.regression_threshold_ms)
    for (name, value) in report.result.metrics
        summary["metric.$name"] = value
    end
    return summary
end

function benchmark_warnings(report::BenchmarkReport; noise_ratio_threshold::Real)
    elapsed = [sample.elapsed_ms for sample in report.samples]
    warnings = String[]
    if length(elapsed) > 1
        mean_elapsed = sum(elapsed) / length(elapsed)
        if mean_elapsed > 0
            noise_ratio = (maximum(elapsed) - minimum(elapsed)) / mean_elapsed
            noise_ratio > noise_ratio_threshold &&
                push!(warnings, "noisy benchmark: elapsed_ms spread ratio $(round(noise_ratio; digits = 4))")
        end
    end
    if !isnothing(report.regression_threshold_ms) && minimum(elapsed) > report.regression_threshold_ms
        push!(
            warnings,
            "regression threshold missed: min elapsed_ms $(round(minimum(elapsed); digits = 4)) > $(report.regression_threshold_ms)",
        )
    end
    return warnings
end

function percentile(values::Vector{Float64}, fraction::Float64)
    sorted = sort(values)
    length(sorted) == 1 && return only(sorted)
    index = 1 + (length(sorted) - 1) * fraction
    lower_index = floor(Int, index)
    upper_index = ceil(Int, index)
    lower_index == upper_index && return sorted[lower_index]
    weight = index - lower_index
    return sorted[lower_index] * (1 - weight) + sorted[upper_index] * weight
end

function normalized_optional_positive_float(value::Nothing, _name::AbstractString)
    return nothing
end

function normalized_optional_positive_float(value::Real, name::AbstractString)
    value > 0 || throw(ArgumentError("$name must be positive"))
    return Float64(value)
end
