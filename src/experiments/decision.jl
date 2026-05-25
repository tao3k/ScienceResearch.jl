"""
    ResearchDecision

Record whether an experiment result is ready for downstream implementation,
needs more evidence, or should be rejected.
"""
struct ResearchDecision
    status::Symbol
    reasons::Vector{String}
    metric_deltas::Dict{String,Float64}
end

const RESEARCH_DECISION_STATUSES = (:promote, :needs_more_evidence, :reject, :stale_evidence)

"""
    compare_baseline(candidate, baseline; metric)

Compare a candidate result against a baseline for a named metric. Positive
values mean the candidate is better for `:higher_is_better`; negative values
mean the candidate is better for `:lower_is_better`.

Throws `ArgumentError` when the requested metric is not declared by the
experiment spec.
"""
function compare_baseline(
    candidate::ExperimentResult,
    baseline::ExperimentResult;
    metric::AbstractString,
)
    candidate_metric = metric_by_name(candidate.spec, metric)
    candidate_value = candidate.metrics[String(metric)]
    baseline_value = baseline.metrics[String(metric)]
    if candidate_metric.direction == :lower_is_better
        return baseline_value - candidate_value
    end
    return candidate_value - baseline_value
end

"""
    metric_threshold_passes(result, metric)

Return whether a result satisfies the threshold declared by `metric`.
Metrics without thresholds always pass this check.
"""
function metric_threshold_passes(result::ExperimentResult, metric::MetricSpec)
    isnothing(metric.threshold) && return true
    value = result.metrics[metric.name]
    if metric.direction == :lower_is_better
        return value <= metric.threshold
    elseif metric.direction == :target
        return value == metric.threshold
    end
    return value >= metric.threshold
end

"""
    threshold_report(result)

Return a dictionary mapping metric names to threshold pass/fail status.
"""
function threshold_report(result::ExperimentResult)
    Dict(metric.name => metric_threshold_passes(result, metric) for metric in result.spec.metrics)
end

"""
    decide_research_promotion(candidate; baseline = nothing, required_delta = 0.0, reject_on_threshold_failure = false, stale = false)

Decide whether an experiment result is a research promotion candidate. A
candidate is promoted only when every metric threshold passes and every
baseline delta is at least `required_delta`.

Throws `ArgumentError` when `required_delta` is negative, when the baseline uses
a different experiment spec, or when `stale` is true while
`reject_on_threshold_failure` is also true.
"""
function decide_research_promotion(
    candidate::ExperimentResult;
    baseline::Union{Nothing,ExperimentResult} = nothing,
    required_delta::Real = 0,
    reject_on_threshold_failure::Bool = false,
    stale::Bool = false,
)
    required_delta >= 0 || throw(ArgumentError("required_delta must be non-negative"))
    !(stale && reject_on_threshold_failure) ||
        throw(ArgumentError("stale evidence cannot also request threshold rejection"))
    reasons = String[]
    thresholds = threshold_report(candidate)
    for metric in candidate.spec.metrics
        get(thresholds, metric.name, false) || push!(reasons, "threshold failed: $(metric.name)")
    end

    deltas = Dict{String,Float64}()
    if !isnothing(baseline)
        baseline.spec === candidate.spec ||
            throw(ArgumentError("baseline and candidate must use the same experiment spec"))
        for metric in candidate.spec.metrics
            delta = compare_baseline(candidate, baseline; metric = metric.name)
            deltas[metric.name] = delta
            delta >= required_delta || push!(reasons, "baseline delta failed: $(metric.name)")
        end
    end

    status = research_decision_status(; reasons, reject_on_threshold_failure, stale)
    return ResearchDecision(status, reasons, deltas)
end

function research_decision_status(; reasons::Vector{String}, reject_on_threshold_failure::Bool, stale::Bool)
    stale && return :stale_evidence
    isempty(reasons) && return :promote
    reject_on_threshold_failure && return :reject
    return :needs_more_evidence
end

function metric_by_name(spec::ExperimentSpec, name::AbstractString)
    for metric in spec.metrics
        metric.name == String(name) && return metric
    end
    throw(ArgumentError("unknown experiment metric: $name"))
end
