using Downloads

const HIGHLIGHT_ASSET_CACHE = Dict{String,String}()
const HIGHLIGHT_ASSET_URLS = (
    light_css = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github.min.css",
    dark_css = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github-dark.min.css",
    core_js = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/highlight.min.js",
    julia_js = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/languages/julia.min.js",
    markdown_js = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/languages/markdown.min.js",
    latex_js = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/languages/latex.min.js",
)

function _html_escape(text)
    escaped = replace(string(text), "&" => "&amp;")
    escaped = replace(escaped, "<" => "&lt;")
    escaped = replace(escaped, ">" => "&gt;")
    escaped = replace(escaped, "\"" => "&quot;")
    return escaped
end

function _asset_text(url)
    return get!(HIGHLIGHT_ASSET_CACHE, url) do
        path = Downloads.download(url)
        try
            read(path, String)
        finally
            rm(path; force = true)
        end
    end
end

function _highlight_asset_blocks(; embed_highlight_assets::Bool)
    if !embed_highlight_assets
        return """
        <link rel="stylesheet" href="$(HIGHLIGHT_ASSET_URLS.light_css)">
        <link rel="stylesheet" media="(prefers-color-scheme: dark)" href="$(HIGHLIGHT_ASSET_URLS.dark_css)">
        <script src="$(HIGHLIGHT_ASSET_URLS.core_js)"></script>
        <script src="$(HIGHLIGHT_ASSET_URLS.julia_js)"></script>
        <script src="$(HIGHLIGHT_ASSET_URLS.markdown_js)"></script>
        <script src="$(HIGHLIGHT_ASSET_URLS.latex_js)"></script>
        """
    end

    return """
        <style>
    $(_asset_text(HIGHLIGHT_ASSET_URLS.light_css))
        </style>
        <style media="(prefers-color-scheme: dark)">
    $(_asset_text(HIGHLIGHT_ASSET_URLS.dark_css))
        </style>
        <script>
    $(_asset_text(HIGHLIGHT_ASSET_URLS.core_js))
        </script>
        <script>
    $(_asset_text(HIGHLIGHT_ASSET_URLS.julia_js))
        </script>
        <script>
    $(_asset_text(HIGHLIGHT_ASSET_URLS.markdown_js))
        </script>
        <script>
    $(_asset_text(HIGHLIGHT_ASSET_URLS.latex_js))
        </script>
    """
end

"""
    page_shell(; title, body, project_title, current_file, embed_highlight_assets)

Wrap rendered notebook HTML in the shared ScienceResearch publication shell,
including responsive tables, MathJax, and Julia/Markdown/LaTeX highlighting.
"""
function page_shell(;
    title,
    body,
    project_title = "ScienceResearch notebooks",
    current_file = nothing,
    embed_highlight_assets::Bool = true,
)
    home_link =
        isnothing(current_file) ? "" : "<a class=\"nav-link\" href=\"index.html\">Notebook index</a>"
    highlight_assets = _highlight_asset_blocks(; embed_highlight_assets)
    return """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>$(_html_escape(title))</title>
        <style>
          :root {
            color-scheme: light dark;
            --bg: #f7f7f4;
            --panel: #ffffff;
            --text: #1f2523;
            --muted: #5b6661;
            --line: #d8ded8;
            --accent: #146c5f;
            --code-bg: #f0f3ef;
            --shadow: 0 18px 45px rgba(31, 37, 35, 0.08);
          }
          @media (prefers-color-scheme: dark) {
            :root {
              --bg: #111513;
              --panel: #181f1c;
              --text: #edf3ef;
              --muted: #aab6af;
              --line: #303a35;
              --accent: #6ed6c4;
              --code-bg: #0d1210;
              --shadow: 0 18px 45px rgba(0, 0, 0, 0.28);
            }
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            background: var(--bg);
            color: var(--text);
            font-family:
              ui-sans-serif,
              system-ui,
              -apple-system,
              BlinkMacSystemFont,
              "Segoe UI",
              sans-serif;
            line-height: 1.58;
          }
          a { color: var(--accent); }
          .shell {
            width: min(1120px, calc(100% - 32px));
            margin: 0 auto;
            padding: 32px 0 56px;
          }
          .site-header {
            display: flex;
            justify-content: space-between;
            gap: 16px;
            align-items: center;
            margin-bottom: 24px;
            color: var(--muted);
          }
          .brand {
            color: var(--text);
            font-weight: 700;
            letter-spacing: 0;
          }
          .nav-link {
            border: 1px solid var(--line);
            border-radius: 6px;
            padding: 7px 10px;
            text-decoration: none;
            background: var(--panel);
          }
          .notebook-panel {
            background: var(--panel);
            border: 1px solid var(--line);
            border-radius: 8px;
            box-shadow: var(--shadow);
            padding: clamp(20px, 4vw, 46px);
            overflow: hidden;
          }
          .index-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: 12px;
            padding: 0;
            list-style: none;
          }
          .index-card {
            min-height: 92px;
            border: 1px solid var(--line);
            border-radius: 8px;
            background: var(--panel);
            padding: 16px;
          }
          .index-card a {
            display: block;
            font-weight: 700;
            text-decoration: none;
          }
          .index-card code {
            display: block;
            margin-top: 8px;
            color: var(--muted);
            overflow-wrap: anywhere;
          }
          pre {
            overflow-x: auto;
            border: 1px solid var(--line);
            border-radius: 6px;
            background: var(--code-bg);
            padding: 12px 14px;
          }
          code {
            font-family:
              ui-monospace,
              SFMono-Regular,
              Menlo,
              Monaco,
              Consolas,
              "Liberation Mono",
              monospace;
          }
          table {
            width: 100%;
            border-collapse: collapse;
            margin: 16px 0;
          }
          th, td {
            border: 1px solid var(--line);
            padding: 8px 10px;
            text-align: left;
            vertical-align: top;
          }
          .tex {
            overflow-x: auto;
            padding: 4px 0;
          }
          .markdown,
          .code-output {
            min-width: 0;
            max-width: 100%;
          }
          .markdown {
            overflow-x: auto;
          }
          .markdown > table,
          .code-output table {
            display: block;
            max-width: 100%;
            overflow-x: auto;
            white-space: nowrap;
          }
          .markdown td,
          .markdown th,
          .code-output td,
          .code-output th {
            overflow-wrap: anywhere;
            word-break: normal;
          }
          .markdown p,
          .markdown li,
          .code-output {
            overflow-wrap: anywhere;
          }
        </style>
        $highlight_assets
        <script>
          window.MathJax = {
            tex: {
              inlineMath: [['\$', '\$'], ['\\\\(', '\\\\)']],
              displayMath: [['\$\$', '\$\$'], ['\\\\[', '\\\\]']]
            },
            svg: { fontCache: 'global' }
          };
        </script>
        <script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>
        <script>
          window.addEventListener('DOMContentLoaded', () => {
            if (window.hljs) {
              document
                .querySelectorAll(
                  [
                    'pre code.language-julia',
                    'pre code.language-markdown',
                    'pre code.language-md',
                    'pre code.language-latex',
                    'pre code.language-tex'
                  ].join(',')
                )
                .forEach((block) => {
                  hljs.highlightElement(block);
                });
              hljs.highlightAll();
            }
          });
        </script>
      </head>
      <body>
        <div class="shell">
          <header class="site-header">
            <div class="brand">$(_html_escape(project_title))</div>
            $home_link
          </header>
          <main class="notebook-panel">
    $body
          </main>
        </div>
      </body>
    </html>
    """
end

"""
    notebook_index_html(files; project_title, embed_highlight_assets)

Render the static notebook index page for a set of published notebook files.
"""
function notebook_index_html(files; project_title = "ScienceResearch notebooks", embed_highlight_assets::Bool = true)
    links = [
        """
            <li class="index-card">
              <a href="$(_html_escape(splitext(file)[1])).html">$(_html_escape(notebook_title(file)))</a>
              <code>$(_html_escape(file))</code>
            </li>
        """
        for file in files
    ]
    body = """
        <h1>$(_html_escape(project_title))</h1>
        <p>
          Static HTML exports for executable research notebooks. Math rendering
          is enabled for expressions such as
          <span class="tex">\\(G = (V, E)\\)</span>.
        </p>
        <ul class="index-grid">
    $(join(links, "\n"))
        </ul>
    """
    return page_shell(; title = project_title, body, project_title, embed_highlight_assets)
end

"""
    write_notebook_index(output_dir, files; project_title, embed_highlight_assets)

Write `index.html` for a notebook publication directory and return the written
path.
"""
function write_notebook_index(output_dir, files; project_title = "ScienceResearch notebooks", embed_highlight_assets::Bool = true)
    mkpath(output_dir)
    write(
        joinpath(output_dir, "index.html"),
        notebook_index_html(files; project_title, embed_highlight_assets),
    )
    return joinpath(output_dir, "index.html")
end
