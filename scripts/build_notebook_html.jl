#!/usr/bin/env julia

using ScienceResearch

if abspath(PROGRAM_FILE) == @__FILE__
    build_notebook_html(parse_notebook_html_build_config(ARGS; package_root = dirname(@__DIR__)))
end
