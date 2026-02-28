---
name: lsp-lite
description: Lightweight LSP diagnostics and symbol-aware code intelligence for Pi across Go, Python, TypeScript/JavaScript, Bash, Lua, and Terraform.
user-invocable: true
---

# lsp-lite

Use this capability when you need quick diagnostics or code intelligence from the Pi `lsp` tool.

## Core actions

- `status`
- `diagnostics`
- `definition`
- `references`
- `hover`
- `symbols`
- `rename`
- `reload`

## Typical workflow

1. Run `lsp action=diagnostics file=...` to surface issues.
2. Use symbol-aware actions (`definition`, `references`, `hover`, `symbols`) while editing.
3. Use `rename` with preview first, then apply when safe.
