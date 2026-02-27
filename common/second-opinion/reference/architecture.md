# Architecture

How `/second-opinion` orchestrates external AI calls.

## System Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Opus (main agent)                                          │
│  1. Parse args (AI spec, question)                          │
│  2. Invoke /complete-prompt skill (Skill tool)              │  ← Saves to .prompts/
│  3. Spawn ONE Sonnet coordinator sub-agent                  │
│  4. Receive raw results                                     │
│  5. Verify responses (quality check)                        │
│  6. Synthesize responses (needs intelligence)               │
└─────────────────────────────────────────────────────────────┘
           │                              │
           │ Skill tool                   │ Task tool (model: "sonnet")
           ▼                              ▼
┌──────────────────────┐    ┌─────────────────────────────────┐
│  /complete-prompt    │    │  Sonnet coordinator             │
│  • Reads templates   │    │  • Reads ai-registry.yaml       │
│  • Extracts context  │    │  • Runs ONE bash command:       │
│  • Saves .prompts/   │    │    run-parallel.sh              │
│  • Returns file path │    │  • Parses delimited output      │
└──────────────────────┘    │  • Returns formatted results    │
                            └─────────────────────────────────┘
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
`/so` invokes `/cp` via Skill tool — single source of truth for context generation. This ensures:
- Consistent XML+CDATA structure
- All 9 modes available
- Future improvements to `/cp` automatically benefit `/so`

### Token Efficiency
Opus handles intelligent work (parsing, synthesis); Sonnet handles mechanical orchestration (~15x cheaper). The coordinator runs a single bash command (`run-parallel.sh`) instead of spawning N sub-agents, eliminating N extra API calls.

### File-Based Handoff
Prompts saved to `.prompts/` avoid CLI length limits and enable debugging. Responses saved to `.responses/` for later reference.

## Component Responsibilities

| Component | Intelligence Level | Tasks |
|-----------|-------------------|-------|
| Opus (main) | High | Parse input, select mode, synthesize |
| /complete-prompt | Medium | Template filling, context extraction |
| Sonnet coordinator | Low | Run `run-parallel.sh`, parse delimited output |
| run-parallel.sh | None (bash) | Launch N `ask-ai-zellij.sh` in parallel, monitor liveness |
| ask-ai-zellij.sh | None (bash) | Execute single AI CLI, stream to Zellij pane |
