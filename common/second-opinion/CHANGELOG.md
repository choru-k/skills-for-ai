# Second Opinion Changelog

## Version History

- 2026-02-11: **v1.2 released** — Portable path handling
  - Replace hardcoded `$HOME/dotfiles` paths with `{{CALL_AI_DIR}}` placeholder
  - Add CALL_AI_DIR resolution step to coordinator workflow
  - Make debugging commands use relative paths

- 2026-02-11: **v1.1** — Coordinator template system
  - XML and markdown coordinator templates
  - Parallel AI execution via run-parallel.sh
  - Reference docs for workflow, synthesis, and troubleshooting

- 2026-02-10: **v1.0** — Initial version
  - Second opinions from Codex, Gemini, Claude
  - Integration with complete-prompt and call-ai skills
  - Synthesis with agreement/disagreement highlighting
