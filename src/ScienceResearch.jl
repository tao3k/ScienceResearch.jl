"""
    ScienceResearch

Own research-time algorithm experiment contracts, Pluto notebook validation,
and static publication helpers for research packages. Domain packages keep
domain algorithms and fixtures; this module provides the reusable substrate for
running, comparing, recording, and publishing algorithm evidence.
"""
module ScienceResearch

include("config.jl")
include("experiments.jl")
include("notebooks.jl")
include("html.jl")
include("publish.jl")

export NotebookHtmlBuildConfig,
    parse_notebook_html_build_config,
    discover_pluto_notebooks,
    is_pluto_notebook,
    notebook_title,
    validate_pluto_notebook,
    validate_pluto_notebook_file,
    notebook_index_html,
    page_shell,
    write_notebook_index,
    build_notebook_html,
    DatasetSpec,
    WorkloadSpec,
    ExperimentSpec,
    MetricSpec,
    ExperimentResult,
    run_experiment,
    compare_baseline,
    write_result_artifact

end
