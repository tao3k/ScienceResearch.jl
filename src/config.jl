"""
    NotebookHtmlBuildConfig

Configuration for publishing a directory of Pluto notebooks as static HTML.
The fields are intentionally domain-neutral so research packages can provide
their own notebook directory, output directory, and project title.

Dispatch extension pattern: the keyword constructor normalizes string-like
fields while the type remains the single public configuration record.
"""
struct NotebookHtmlBuildConfig
    package_root::String
    notebook_dir::String
    output_dir::String
    previous_dir::Union{Nothing,String}
    project_title::String
    max_concurrent_runs::Int
    use_distributed::Bool
    append_build_context::Bool
    dry_run::Bool
    include_backups::Bool
    embed_highlight_assets::Bool
end

"""
    NotebookHtmlBuildConfig(; kwargs...)

Build a `NotebookHtmlBuildConfig` from keyword arguments while normalizing
string-like fields to `String`.

Dispatch extension pattern: this constructor is the only public method family
extension for `NotebookHtmlBuildConfig`; it preserves one owner file for the
configuration API.
"""
function NotebookHtmlBuildConfig(;
    package_root::AbstractString = pwd(),
    notebook_dir::AbstractString = joinpath(package_root, "notebooks"),
    output_dir::AbstractString = joinpath(package_root, "build", "notebooks", "html"),
    previous_dir::Union{Nothing,AbstractString} = nothing,
    project_title::AbstractString = "ScienceResearch notebooks",
    max_concurrent_runs::Int = parse(Int, get(ENV, "SCIENCE_RESEARCH_NOTEBOOK_HTML_MAX_CONCURRENT_RUNS", "4")),
    use_distributed::Bool = get(ENV, "SCIENCE_RESEARCH_NOTEBOOK_HTML_SEQUENTIAL", "0") != "1",
    append_build_context::Bool = get(ENV, "SCIENCE_RESEARCH_NOTEBOOK_HTML_APPEND_BUILD_CONTEXT", "0") == "1",
    dry_run::Bool = false,
    include_backups::Bool = false,
    embed_highlight_assets::Bool = true,
)
    return NotebookHtmlBuildConfig(
        String(package_root),
        String(notebook_dir),
        String(output_dir),
        isnothing(previous_dir) ? nothing : String(previous_dir),
        String(project_title),
        max_concurrent_runs,
        use_distributed,
        append_build_context,
        dry_run,
        include_backups,
        embed_highlight_assets,
    )
end

function _usage()
    return """
    Usage:
      julia --project=. scripts/build_notebook_html.jl [options]

    Options:
      --package-root <path>            Package root used for relative output.
      --notebook-dir <path>            Directory containing Pluto notebooks.
      --output-dir <path>              Directory for generated HTML files.
      --previous-dir <path>            Directory containing previous HTML cache.
      --project-title <text>           Title shown in generated HTML.
      --max-concurrent-runs <n>        Maximum parallel Pluto notebook runs.
      --sequential                     Disable distributed parallel notebook runs.
      --parallel                       Enable distributed parallel notebook runs.
      --append-build-context           Append Pluto package context to HTML output.
      --include-backups                Include backup notebook files.
      --no-embedded-highlight-assets   Link highlighting assets instead of embedding them.
      --dry-run                        Print selected notebooks without building.
      --help                           Show this help text.
    """
end

function _take_arg(args, index, name)
    next_index = index + 1
    next_index <= length(args) || error("missing value for $name")
    return args[next_index], next_index
end

"""
    parse_notebook_html_build_config(args = ARGS; package_root = pwd())

Parse command-line style arguments into a `NotebookHtmlBuildConfig` without
assuming a specific domain package. This is the stable entry point for thin
publication scripts.

Throws an `ErrorException` when an option is unknown, when a required option
value is missing, or when `--max-concurrent-runs` is less than one.
"""
function parse_notebook_html_build_config(args = ARGS; package_root = pwd())
    default = NotebookHtmlBuildConfig(; package_root = abspath(package_root))
    root = default.package_root
    notebook_dir = get(ENV, "SCIENCE_RESEARCH_NOTEBOOK_DIR", default.notebook_dir)
    output_dir = get(ENV, "SCIENCE_RESEARCH_NOTEBOOK_HTML_OUT", default.output_dir)
    previous_dir = get(ENV, "SCIENCE_RESEARCH_NOTEBOOK_HTML_PREVIOUS_DIR", "")
    project_title = get(ENV, "SCIENCE_RESEARCH_NOTEBOOK_TITLE", default.project_title)
    max_concurrent_runs = default.max_concurrent_runs
    use_distributed = default.use_distributed
    append_build_context = default.append_build_context
    dry_run = false
    include_backups = false
    embed_highlight_assets = default.embed_highlight_assets

    index = 1
    while index <= length(args)
        arg = args[index]
        if arg == "--help"
            print(_usage())
            exit(0)
        elseif arg == "--package-root"
            root, index = _take_arg(args, index, arg)
        elseif startswith(arg, "--package-root=")
            root = last(split(arg, "="; limit = 2))
        elseif arg == "--notebook-dir"
            notebook_dir, index = _take_arg(args, index, arg)
        elseif startswith(arg, "--notebook-dir=")
            notebook_dir = last(split(arg, "="; limit = 2))
        elseif arg == "--output-dir"
            output_dir, index = _take_arg(args, index, arg)
        elseif startswith(arg, "--output-dir=")
            output_dir = last(split(arg, "="; limit = 2))
        elseif arg == "--previous-dir"
            previous_dir, index = _take_arg(args, index, arg)
        elseif startswith(arg, "--previous-dir=")
            previous_dir = last(split(arg, "="; limit = 2))
        elseif arg == "--project-title"
            project_title, index = _take_arg(args, index, arg)
        elseif startswith(arg, "--project-title=")
            project_title = last(split(arg, "="; limit = 2))
        elseif arg == "--max-concurrent-runs"
            value, next_index = _take_arg(args, index, arg)
            max_concurrent_runs = parse(Int, value)
            index = next_index
        elseif startswith(arg, "--max-concurrent-runs=")
            max_concurrent_runs = parse(Int, last(split(arg, "="; limit = 2)))
        elseif arg == "--sequential"
            use_distributed = false
        elseif arg == "--parallel"
            use_distributed = true
        elseif arg == "--append-build-context"
            append_build_context = true
        elseif arg == "--include-backups"
            include_backups = true
        elseif arg == "--no-embedded-highlight-assets"
            embed_highlight_assets = false
        elseif arg == "--dry-run"
            dry_run = true
        else
            error("unknown argument: $arg")
        end
        index += 1
    end

    max_concurrent_runs >= 1 || error("--max-concurrent-runs must be positive")

    absolute_root = abspath(root)
    normalized_previous_dir = isempty(previous_dir) ? nothing : abspath(previous_dir)
    return NotebookHtmlBuildConfig(;
        package_root = absolute_root,
        notebook_dir = abspath(notebook_dir),
        output_dir = abspath(output_dir),
        previous_dir = normalized_previous_dir,
        project_title,
        max_concurrent_runs,
        use_distributed,
        append_build_context,
        dry_run,
        include_backups,
        embed_highlight_assets,
    )
end
