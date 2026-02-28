# lsp-lite smoke tests

Fixtures and a one-command smoke test for the Pi `lsp` extension.

## Run

From any shell where Pi is installed:

```bash
~/.pi/agent/extensions/lsp-lite/smoke/run.sh
```

The script runs diagnostics for Go, Python, Bash, TypeScript, Lua, and Terraform, plus code-intel actions for:
- Go (`definition`, `references`, `hover`, `symbols`, `rename` preview)
- Python (`definition`, `hover`)
- TypeScript (`references`, `symbols`, `rename` preview + apply on temp copy)
- Lua (`symbols`, `hover`)
- Terraform unsupported-capability check (`renameProvider=false`)

JSON logs are written to a temp directory and printed at the end.
