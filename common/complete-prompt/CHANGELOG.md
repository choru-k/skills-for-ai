# Complete Prompt Changelog

## Version History

- 2026-02-11: **v1.9 released** — Reference mode (`--refs`)
  - Added `--refs` modifier for token-efficient handoffs
  - File paths + key blocks instead of full CDATA contents
  - For use when receiving AI has codebase access (e.g., `/second-opinion`)

- 2026-02-05: **v1.8 released** — Domain-specific modes
  - Added `research` mode for literature review and fact-finding
  - Added `career` mode for resume, job search, interview prep
  - Added `learning` mode for study plans and skill acquisition
  - Evolved from generic mode based on 6-model second opinion

- 2026-02-04: **v1.7 released** — General mode and examples
  - Added `general` mode for non-technical handoffs
  - Added inline examples for all modes
  - Created examples directory with detailed mode examples

- 2026-02-03: **v1.6 released** — Diff mode and pre-flight checklist
  - Added `diff` mode for code review contexts
  - Added pre-flight checklist before generation
  - Improved mode-specific behavior documentation

- 2026-02-02: **v1.5 released** — Architect mode
  - Added `architect` mode for design discussions
  - Added strategic information placement guidance

- 2026-02-01: **v1.4 released** — Debug mode
  - Added `debug` mode for error troubleshooting
  - Added success criteria and non-goals sections

- 2026-01-31: **v1.3 released** — Brief mode
  - Added `brief` mode for token-efficient handoffs
  - Added token budget guidelines

- 2026-01-30: **v1.2 released** — XML + CDATA format
  - Switched from Markdown to XML with CDATA
  - Added output file saving

- 2026-01-29: **v1.1 released** — Template structure
  - Standardized template sections
  - Added roles and responsibilities

- 2026-01-28: **v1.0 released** — Initial release
  - Basic context handoff functionality
  - Full mode only
