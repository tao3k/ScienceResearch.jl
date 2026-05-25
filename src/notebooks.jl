"""
    is_pluto_notebook(path)

Return whether `path` starts with Pluto's notebook sentinel line.
"""
function is_pluto_notebook(path::AbstractString)
    isfile(path) || return false
    open(path, "r") do io
        eof(io) && return false
        return readline(io) == "### A Pluto.jl notebook ###"
    end
end

function _is_backup_notebook(file::AbstractString)
    lowercase_file = lowercase(file)
    return occursin("backup", lowercase_file) || occursin(" copy", lowercase_file)
end

"""
    discover_pluto_notebooks(notebook_dir; include_backups = false)

Return sorted Pluto notebook filenames from `notebook_dir`, excluding backup
copies by default so publication runs stay deterministic.

Throws an `ErrorException` when the notebook directory is missing or no Pluto
notebooks are discoverable.
"""
function discover_pluto_notebooks(notebook_dir::AbstractString; include_backups::Bool = false)
    isdir(notebook_dir) || error("notebook directory does not exist: $notebook_dir")
    files = sort(filter(readdir(notebook_dir)) do file
        path = joinpath(notebook_dir, file)
        endswith(file, ".jl") && is_pluto_notebook(path) &&
            (include_backups || !_is_backup_notebook(file))
    end)
    isempty(files) && error("no Pluto notebooks found in $notebook_dir")
    return files
end

"""
    notebook_title(file)

Convert a notebook filename into a human-readable title for generated indexes.
"""
function notebook_title(file::AbstractString)
    return replace(splitext(basename(file))[1], "_" => " ")
end

"""
    validate_pluto_notebook(notebook_text)

Return notebook discipline issues for a Pluto notebook text. The first
discipline slice checks the cell order block, markdown-before-code layout, and
one-function-per-code-cell convention.
"""
function validate_pluto_notebook(notebook_text::AbstractString)
    issues = String[]
    notebook_parts = split(notebook_text, "# ╔═╡ Cell order:"; limit = 2)
    if length(notebook_parts) != 2
        push!(issues, "missing Pluto cell order block")
        return issues
    end

    notebook_body = notebook_parts[1]
    cell_order = notebook_parts[2]
    if occursin(r"(?m)^# [╟╠]", notebook_body)
        push!(issues, "cell order marker appears in notebook body")
    end

    order_markers = collect(eachmatch(r"(?m)^# ([╟╠])(?:─|═╡?)([0-9a-f-]+)$", cell_order))
    isempty(order_markers) && push!(issues, "cell order block has no cells")
    for index in eachindex(order_markers)
        if order_markers[index].captures[1] == "╠"
            if index == 1 || order_markers[index - 1].captures[1] != "╟"
                push!(issues, "code cell $(order_markers[index].captures[2]) is not preceded by markdown")
            end
        end
    end

    body_cells = collect(eachmatch(r"(?ms)^# ╔═╡ ([0-9a-f-]+)\n(.+?)(?=^# ╔═╡ |\z)", notebook_body))
    isempty(body_cells) && push!(issues, "notebook body has no cells")
    for cell in body_cells
        cell_code = cell.captures[2]
        if !startswith(lstrip(cell_code), "md\"\"\"")
            function_defs = collect(eachmatch(r"(?m)^function\s+", cell_code))
            if length(function_defs) > 1
                push!(issues, "code cell $(cell.captures[1]) defines more than one function")
            end
        end
    end
    return issues
end

"""
    validate_pluto_notebook_file(path)

Read a notebook file and return the same discipline issues as
`validate_pluto_notebook`.
"""
function validate_pluto_notebook_file(path::AbstractString)
    is_pluto_notebook(path) || return ["not a Pluto notebook: $path"]
    return validate_pluto_notebook(read(path, String))
end

"""
    validate_notebook_evidence(notebook_text, artifact_dir)

Return evidence synchronization issues for `scienceresearch-artifact: <path>`
references embedded in a notebook. Paths are resolved under `artifact_dir`.

Throws `ErrorException` when `artifact_dir` does not exist.
"""
function validate_notebook_evidence(notebook_text::AbstractString, artifact_dir::AbstractString)
    isdir(artifact_dir) || error("artifact directory does not exist: $artifact_dir")
    issues = String[]
    refs = collect(eachmatch(r"scienceresearch-artifact:\s*([^\s\"`]+)", notebook_text))
    isempty(refs) && push!(issues, "notebook does not reference experiment evidence")
    for ref in refs
        relative_path = ref.captures[1]
        if isabspath(relative_path) || any(part -> part == "..", splitpath(relative_path))
            push!(issues, "artifact reference must be relative and stay under artifact_dir: $relative_path")
            continue
        end
        path = joinpath(artifact_dir, relative_path)
        if !isfile(path)
            push!(issues, "artifact reference does not exist: $relative_path")
            continue
        end
        try
            manifest = read_experiment_manifest(path)
            get(manifest, "schema", "") == "scienceresearch.experiment_manifest.v1" ||
                push!(issues, "artifact reference has unsupported schema: $relative_path")
        catch err
            push!(issues, "artifact reference is not readable: $relative_path ($(typeof(err)))")
        end
    end
    return issues
end
