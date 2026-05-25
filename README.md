# ScienceResearch.jl

ScienceResearch.jl is a small Julia library for executable research notebooks.
It provides reusable Pluto notebook discovery, notebook discipline checks, and
static HTML publication helpers. Domain packages keep their algorithms,
fixtures, and notebooks; ScienceResearch owns the shared publication substrate.

## Boundary

- ScienceResearch owns generic notebook validation and HTML publication.
- Domain packages own domain APIs, fixtures, and package activation policy.
- `JuliaLangProjectHarness.jl` is used as a development/test dependency only.

## Minimal Usage

```julia
using ScienceResearch

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
