# Synthesis Guide

How to merge and present external AI responses.

## Merging Rules

- **Nearly identical responses**: Group under combined header
- **Minor wording differences**: Merge into single response
- **Different conclusions**: Show separately with comparison
- **Unique insights**: Always highlight

## Output Formats

### Single/Few Responses

```
## CODEX (gpt-5.2-codex) ##
────────────────────────────────────────
[Response]
────────────────────────────────────────

## MY SYNTHESIS ##
────────────────────────────────────────
[Your analysis]
────────────────────────────────────────
```

### Full Consensus (`:all` mode)

When all models agree:

```
## CONSENSUS: CODEX, GEMINI PRO, CLAUDE SONNET ##
────────────────────────────────────────
[Shared response - shown once]
────────────────────────────────────────

## FAST MODELS ##
────────────────────────────────────────
⬆️ Agree with above.
────────────────────────────────────────

## MY SYNTHESIS ##
────────────────────────────────────────
All models reached consensus: [summary]
────────────────────────────────────────
```

### Divergent Responses

When models disagree:

```
## CODEX vs GEMINI ##
────────────────────────────────────────
Codex suggests X because...
Gemini suggests Y because...

Key difference: [analysis]
────────────────────────────────────────
```

### Partial Consensus with Unique Insights

```
## CONSENSUS: CODEX, GEMINI ##
────────────────────────────────────────
[Shared conclusion]
────────────────────────────────────────

## UNIQUE INSIGHT: CLAUDE ##
────────────────────────────────────────
[Different perspective worth highlighting]
────────────────────────────────────────

## MY SYNTHESIS ##
────────────────────────────────────────
[Analysis incorporating all viewpoints]
────────────────────────────────────────
```

## Consensus Detection

### Strong consensus signals
- Same recommendation with minor wording differences
- All models cite the same tradeoffs
- Fast models confirm thorough models

### Divergence signals
- Different recommendations
- Conflicting tradeoff analyses
- One model raises concerns others don't

### How to handle divergence

1. **Present divergent views fairly** — don't favor one AI
2. **Analyze why they differ** — different assumptions? different contexts?
3. **Offer your synthesis** — Claude's perspective as tiebreaker
4. **Note confidence level** — full consensus = high confidence
