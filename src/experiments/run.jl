"""
    run_experiment(spec, runner)

Run `runner(spec)` and require it to return an `ExperimentResult` for `spec`.

Throws `ArgumentError` when the runner does not return `ExperimentResult`, or
when the returned result belongs to a different spec.
"""
function run_experiment(spec::ExperimentSpec, runner)
    result = runner(spec)
    result isa ExperimentResult ||
        throw(ArgumentError("experiment runner must return ExperimentResult"))
    result.spec === spec || throw(ArgumentError("experiment runner returned a result for another spec"))
    return result
end

function run_experiment(runner, spec::ExperimentSpec)
    return run_experiment(spec, runner)
end
