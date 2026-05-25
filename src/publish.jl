using PlutoStaticHTML: BuildOptions, OutputOptions, build_notebooks, html_output

"""
    build_notebook_html(config = parse_notebook_html_build_config())

Build static HTML for every discovered Pluto notebook and return the published
notebook filenames. In dry-run mode it only prints and returns the selected
files.
"""
function build_notebook_html(config::NotebookHtmlBuildConfig = parse_notebook_html_build_config())
    files = discover_pluto_notebooks(config.notebook_dir; include_backups = config.include_backups)
    if config.dry_run
        println("ScienceResearch Pluto notebooks selected for HTML export:")
        foreach(file -> println(file), files)
        return files
    end

    mkpath(config.output_dir)
    previous_dir = isnothing(config.previous_dir) && isdir(config.output_dir) ? config.output_dir : config.previous_dir
    build_options = BuildOptions(
        config.notebook_dir;
        write_files = false,
        previous_dir,
        output_format = html_output,
        use_distributed = config.use_distributed,
        max_concurrent_runs = config.max_concurrent_runs,
    )
    output_options = OutputOptions(; append_build_context = config.append_build_context)
    outputs = build_notebooks(build_options, files, output_options)

    for file in files
        output = only(outputs[file])
        output_path = joinpath(config.output_dir, "$(splitext(file)[1]).html")
        write(
            output_path,
            page_shell(;
                title = "$(config.project_title): $(notebook_title(file))",
                body = output,
                project_title = config.project_title,
                current_file = file,
                embed_highlight_assets = config.embed_highlight_assets,
            ),
        )
        println("wrote $(relpath(output_path, config.package_root))")
    end
    index_path = write_notebook_index(
        config.output_dir,
        files;
        project_title = config.project_title,
        embed_highlight_assets = config.embed_highlight_assets,
    )
    println("wrote $(relpath(index_path, config.package_root))")
    return files
end
