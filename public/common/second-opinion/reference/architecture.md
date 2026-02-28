# Architecture

How `/second-opinion` orchestrates external AI calls.

## System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Main agent                                                 │
│  1. Parse args (AI spec, question)                          │
│  2. Run complete-prompt workflow with --refs               │  ← Saves to .prompts/
│  3. Execute via coordinator (preferred) or direct fallback │
│  4. Receive raw results                                     │
│  5. Verify responses (quality check)                        │
│  6. Synthesize responses (needs intelligence)               │
└─────────────────────────────────────────────────────────────┘
           │                              │
           │ complete-prompt workflow     │ coordinator / direct bash
           ▼                              ▼
┌──────────────────────┐    ┌─────────────────────────────────┐
│  complete-prompt     │    │  AI call orchestration          │
│  • Reads templates   │    │  • Reads ai-registry.yaml       │
│  • Extracts context  │    │  • Runs run-parallel.sh         │
│  • Saves .prompts/   │    │  • Parses delimited output      │
│  • Returns file path │    │  • Returns formatted results    │
└──────────────────────┘    └─────────────────────────────────┘
                                          │
                                    Bash: run-parallel.sh
                                          │
                             ┌────────────┼────────────┐
                             ▼            ▼            ▼
                      ask-ai-zellij  ask-ai-zellij  ask-ai-zellij
                        [Codex]       [Gemini]       [Claude]
                       (parallel)    (parallel)     (parallel)
```

## Design Rationale

### Skill Composition
`second-opinion` uses the `complete-prompt` workflow as the single source of truth for context generation. This ensures:
- Consistent XML+CDATA structure
- All 9 modes available
- Future improvements to `complete-prompt` automatically benefit `second-opinion`

### Token Efficiency
The main agent handles intelligent work (parsing, synthesis); a lightweight coordinator handles mechanical orchestration when available. The coordinator runs a single bash command (`run-parallel.sh`) instead of spawning N separate workers.

### File-Based Handoff
Prompts saved to `.prompts/` avoid CLI length limits and enable debugging. Responses saved to `.responses/` for later reference.

## Component Responsibilities

| Component | Intelligence Level | Tasks |
|-----------|-------------------|-------|
| Main agent | High | Parse input, select mode, synthesize |
| complete-prompt | Medium | Template filling, context extraction |
| Coordinator agent (optional) | Low | Run `run-parallel.sh`, parse delimited output |
| run-parallel.sh | None (bash) | Launch N `ask-ai-zellij.sh` in parallel, monitor liveness |
| ask-ai-zellij.sh | None (bash) | Execute single AI CLI, stream to Zellij pane |
