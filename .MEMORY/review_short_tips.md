# Review Short Tips

Use this card when:

- you need the fastest mental model of this repo before editing it
- you want to remember this is a broad document-translation product, not just a PDF converter
- you need to keep format-preservation expectations straight

Core idea:

- DocuTranslate is a local LLM-based file translation system
- it supports many file types: `pdf`, `docx`, `xlsx`, `md`, `txt`, `json`, `epub`, subtitles, and more
- it has both CLI and web/API surfaces
- it can also run as an MCP server

What matters most:

- broad format support is the product promise
- format preservation matters especially for `docx` and `xlsx`
- PDF has a major caveat: it is converted to markdown first, so strict original layout is not preserved
- concurrency, multi-provider support, and local/LAN usability are key product strengths

Fast read order:

1. `README.md`
2. `pyproject.toml`
3. `docutranslate/mcp/README.md`
4. any deployment/run docs you are touching
5. this card

High-value commands:

```bash
pip install docutranslate
docutranslate -i
docutranslate -i --host 0.0.0.0
docutranslate --mcp
docutranslate --mcp --transport sse
```

Operational truths:

- web UI and REST API are first-class, not demos
- MCP support is part of the product surface
- local and LAN multi-user use are expected scenarios
- provider/model/base URL/API key are runtime-configured through environment variables
- translation quality and format-preservation expectations depend strongly on file type and conversion path

Current strengths:

- broad format coverage
- practical installation paths: pip, uv, git, docker, portable packages
- web UI + REST API + MCP support in one product
- explicit README caveat about PDF layout loss

Current review cautions:

- do not promise layout fidelity for PDF beyond what the README already states
- if changing translation pipeline behavior, verify file-type-specific expectations
- if touching MCP, preserve the server modes and environment-driven config story
- because this repo is feature broad, avoid casual changes that assume one document type represents all of them

Short reviewer verdict:

- think of this repo as a multi-surface document translation platform
- preserve file-type-specific behavior, web/API/MCP surfaces, and environment-driven provider config
- always keep PDF caveats and format-preservation limits explicit
