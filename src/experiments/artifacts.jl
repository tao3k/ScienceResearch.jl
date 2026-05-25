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
