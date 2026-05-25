# ScienceResearch.jl

ScienceResearch.jl is a Julia library for research-time algorithm validation.
It provides experiment contracts, dataset and workload descriptors, metric
contracts, validation reports, benchmark reports, baseline comparison helpers,
result artifacts, Pluto notebook discipline checks, and static HTML publication
helpers.

The library exists so agents and researchers can test algorithm ideas,
performance assumptions, and feasibility before promoting those ideas into
domain packages or runtime engines.

The core workflow is: define the research contract, validate the data shape,
validate algorithm preconditions, benchmark the candidate, record the evidence
in a notebook or Markdown artifact, and only then move the proven algorithm into
its production package while keeping the notebook evidence synchronized.

## Boundary

- ScienceResearch owns generic research contracts, notebook validation, and
  HTML publication.
- Domain packages own domain algorithms, fixtures, and package activation
  policy.
- `JuliaLangProjectHarness.jl` is used as a development/test dependency only.
- Project-specific APIs such as graph search, OCR routing, ontology proof, or
  runtime gateway policy do not belong in ScienceResearch.

## Documentation

ScienceResearch uses a Johnny.Decimal-style documentation layout:

- [10.01 Boundary](docs/10_foundation/10.01_boundary.md)
- [20.01 Experiment Contract](docs/20_research_contracts/20.01_experiment_contract.md)
- [30.01 Pluto Workflow](docs/30_notebook_workflow/30.01_pluto_workflow.md)
- [40.01 Agent Research Loop](docs/40_agent_research/40.01_agent_research_loop.md)

## Minimal Usage

```julia
using ScienceResearch

dataset = DatasetSpec(;
    id = "synthetic-table",
    description = "Synthetic tabular fixture",
    source = "memory",
    row_count = 10_000,
)
workload = WorkloadSpec(;
    id = "batch-feasibility",
    description = "Batch algorithm feasibility workload",
    scale = Dict("items" => 10_000),
    budget = Dict("latency_ms" => 100.0),
)
quality = MetricSpec(; name = "quality_score")
latency = MetricSpec(; name = "latency_ms", direction = :lower_is_better)
spec = ExperimentSpec(;
    id = "candidate-feasibility",
    title = "Candidate Feasibility",
    dataset,
    workload,
    idea = "vectorized candidate scoring",
    metrics = [quality, latency],
)

result = run_experiment(spec) do active_spec
    ExperimentResult(
        active_spec;
        metrics = Dict("quality_score" => 0.75, "latency_ms" => 8.0),
    )
end

data_report = validate_dataset(dataset, [
    active_dataset -> ValidationCheck(;
        name = "row-count-present",
        passed = !isnothing(active_dataset.row_count),
    ),
])

benchmark = benchmark_experiment(spec, samples = 3) do active_spec
    ExperimentResult(
        active_spec;
        metrics = Dict("quality_score" => 0.75, "latency_ms" => 8.0),
    )
end

decision = decide_research_promotion(result)

config = NotebookHtmlBuildConfig(;
    package_root = pwd(),
    notebook_dir = joinpath(pwd(), "notebooks"),
    output_dir = joinpath(pwd(), "build", "notebooks", "html"),
    project_title = "My research notebooks",
)

files = discover_pluto_notebooks(config.notebook_dir)
build_notebook_html(config)
```

Run the package tests with:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```
