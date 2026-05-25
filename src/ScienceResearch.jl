"""
    ScienceResearch

Own generic Pluto notebook validation and static publication helpers for
research packages. Domain packages keep algorithm notebooks and fixtures; this
module aggregates configuration, notebook checks, HTML shell generation, and
publication APIs.
"""
module ScienceResearch

include("config.jl")
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
    build_notebook_html

end
