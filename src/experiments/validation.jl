"""
    ValidationCheck

Record one deterministic validation check for a dataset, algorithm invariant,
or benchmark precondition.
"""
struct ValidationCheck
    name::String
    passed::Bool
    detail::String
end

"""
    ValidationReport

Collect validation checks for a named subject such as a dataset or algorithm
experiment.
"""
struct ValidationReport
    subject_kind::Symbol
    subject_id::String
    checks::Vector{ValidationCheck}
end

"""
    ValidationCheck(; name, passed, detail = "")

Construct a validation check.

Throws `ArgumentError` when the check name is empty.
"""
function ValidationCheck(;
    name::AbstractString,
    passed::Bool,
    detail::AbstractString = "",
)
    isempty(strip(name)) && throw(ArgumentError("validation check name must not be empty"))
    return ValidationCheck(String(name), passed, String(detail))
end

"""
    ValidationReport(; subject_kind, subject_id, checks)

Construct a validation report.

Throws `ArgumentError` when the subject id is empty or no checks are supplied.
"""
function ValidationReport(;
    subject_kind::Symbol,
    subject_id::AbstractString,
    checks::Vector{ValidationCheck},
)
    isempty(strip(subject_id)) && throw(ArgumentError("validation subject id must not be empty"))
    isempty(checks) && throw(ArgumentError("validation report must contain at least one check"))
    return ValidationReport(subject_kind, String(subject_id), copy(checks))
end

"""
    validate_dataset(dataset, validators)

Run dataset validators and return a `ValidationReport`. Each validator receives
the `DatasetSpec` and must return a `ValidationCheck`.

Throws `ArgumentError` when no validators are supplied or a validator returns a
different value type.
"""
function validate_dataset(dataset::DatasetSpec, validators::Vector)
    checks = run_validators(dataset, validators, "dataset")
    return ValidationReport(; subject_kind = :dataset, subject_id = dataset.id, checks)
end

"""
    validate_algorithm(spec, validators)

Run algorithm-level validators and return a `ValidationReport`. Each validator
receives the `ExperimentSpec` and must return a `ValidationCheck`.

Throws `ArgumentError` when no validators are supplied or a validator returns a
different value type.
"""
function validate_algorithm(spec::ExperimentSpec, validators::Vector)
    checks = run_validators(spec, validators, "algorithm")
    return ValidationReport(; subject_kind = :algorithm, subject_id = spec.id, checks)
end

"""
    validation_passed(report)

Return true when every validation check in `report` passed.
"""
function validation_passed(report::ValidationReport)
    all(check -> check.passed, report.checks)
end

function run_validators(subject, validators::Vector, subject_kind::AbstractString)
    isempty(validators) && throw(ArgumentError("$subject_kind validators must not be empty"))
    checks = ValidationCheck[]
    for validator in validators
        check = validator(subject)
        check isa ValidationCheck ||
            throw(ArgumentError("$subject_kind validator must return ValidationCheck"))
        push!(checks, check)
    end
    return checks
end
