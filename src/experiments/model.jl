"""
    DatasetSpec

Describe a deterministic research dataset or fixture used by an algorithm
experiment.
"""
struct DatasetSpec
    id::String
    description::String
    source::String
    row_count::Union{Nothing,Int}
    byte_size::Union{Nothing,Int}
end

"""
    DatasetSpec(; id, description, source, row_count = nothing, byte_size = nothing)

Construct a dataset descriptor.

Throws `ArgumentError` when the dataset id is empty or optional scale facts are
negative.
"""
function DatasetSpec(;
    id::AbstractString,
    description::AbstractString,
    source::AbstractString,
    row_count::Union{Nothing,Integer} = nothing,
    byte_size::Union{Nothing,Integer} = nothing,
)
    isempty(strip(id)) && throw(ArgumentError("dataset id must not be empty"))
    row_count_value = checked_nonnegative_optional_int(row_count, "row_count")
    byte_size_value = checked_nonnegative_optional_int(byte_size, "byte_size")
    return DatasetSpec(
        String(id),
        String(description),
        String(source),
        row_count_value,
        byte_size_value,
    )
end

"""
    WorkloadSpec

Describe the input shape, scale, and resource budget for an algorithm
feasibility experiment.
"""
struct WorkloadSpec
    id::String
    description::String
    scale::Dict{String,Float64}
    budget::Dict{String,Float64}
end

"""
    WorkloadSpec(; id, description, scale = Dict(), budget = Dict())

Construct a workload descriptor for algorithm and performance validation.

Throws `ArgumentError` when the workload id is empty or any scale or budget
value is negative.
"""
function WorkloadSpec(;
    id::AbstractString,
    description::AbstractString,
    scale::Dict{String,<:Real} = Dict{String,Float64}(),
    budget::Dict{String,<:Real} = Dict{String,Float64}(),
)
    isempty(strip(id)) && throw(ArgumentError("workload id must not be empty"))
    return WorkloadSpec(
        String(id),
        String(description),
        normalized_nonnegative_values(scale, "scale"),
        normalized_nonnegative_values(budget, "budget"),
    )
end

"""
    MetricSpec

Describe one metric that an experiment result must report.
"""
struct MetricSpec
    name::String
    direction::Symbol
    threshold::Union{Nothing,Float64}
end

"""
    MetricSpec(; name, direction = :higher_is_better, threshold = nothing)

Construct a metric descriptor.

Throws `ArgumentError` when the metric direction is not one of
`:higher_is_better`, `:lower_is_better`, or `:target`.
"""
function MetricSpec(;
    name::AbstractString,
    direction::Symbol = :higher_is_better,
    threshold::Union{Nothing,Real} = nothing,
)
    direction in (:higher_is_better, :lower_is_better, :target) ||
        throw(ArgumentError("unsupported metric direction: $direction"))
    return MetricSpec(String(name), direction, isnothing(threshold) ? nothing : Float64(threshold))
end

"""
    ExperimentSpec

Describe one reproducible algorithm experiment, including the dataset,
algorithm name, metric contract, and free-form parameters.
"""
struct ExperimentSpec
    id::String
    title::String
    dataset::DatasetSpec
    workload::WorkloadSpec
    idea::String
    metrics::Vector{MetricSpec}
    parameters::Dict{String,String}
end

"""
    ExperimentSpec(; id, title, dataset, workload, idea, metrics, parameters = Dict())

Construct an experiment descriptor.

Throws `ArgumentError` when the experiment id or idea is empty, or when no
metrics are declared.
"""
function ExperimentSpec(;
    id::AbstractString,
    title::AbstractString,
    dataset::DatasetSpec,
    workload::WorkloadSpec,
    idea::AbstractString,
    metrics::Vector{MetricSpec},
    parameters::Dict{String,String} = Dict{String,String}(),
)
    isempty(strip(id)) && throw(ArgumentError("experiment id must not be empty"))
    isempty(strip(idea)) && throw(ArgumentError("experiment idea must not be empty"))
    isempty(metrics) && throw(ArgumentError("experiment must declare at least one metric"))
    return ExperimentSpec(
        String(id),
        String(title),
        dataset,
        workload,
        String(idea),
        metrics,
        copy(parameters),
    )
end

"""
    ExperimentResult

Record one experiment run with metric values and optional artifact metadata.
"""
struct ExperimentResult
    spec::ExperimentSpec
    metrics::Dict{String,Float64}
    artifacts::Dict{String,String}
    notes::Vector{String}
end

"""
    ExperimentResult(spec; metrics, artifacts = Dict(), notes = String[])

Construct an experiment result and verify that all declared metrics are
present.

Throws `ArgumentError` when a declared metric is missing from `metrics`.
"""
function ExperimentResult(
    spec::ExperimentSpec;
    metrics::Dict{String,<:Real},
    artifacts::Dict{String,String} = Dict{String,String}(),
    notes::Vector{String} = String[],
)
    normalized_metrics = Dict(String(name) => Float64(value) for (name, value) in metrics)
    missing = [metric.name for metric in spec.metrics if !haskey(normalized_metrics, metric.name)]
    isempty(missing) || throw(ArgumentError("missing experiment metrics: $(join(missing, ", "))"))
    return ExperimentResult(spec, normalized_metrics, copy(artifacts), copy(notes))
end

function checked_nonnegative_optional_int(value::Nothing, _name::AbstractString)
    return nothing
end

function checked_nonnegative_optional_int(value::Integer, name::AbstractString)
    value >= 0 || throw(ArgumentError("$name must be non-negative"))
    return Int(value)
end

function normalized_nonnegative_values(values::Dict{String,<:Real}, name::AbstractString)
    normalized = Dict{String,Float64}()
    for (key, value) in values
        value >= 0 || throw(ArgumentError("$name value must be non-negative: $key"))
        normalized[String(key)] = Float64(value)
    end
    return normalized
end
