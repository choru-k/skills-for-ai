# Example: Default Mode (Codex + Gemini)

Demonstrates `/so "question"` — the default mode with 2 responses from Codex and Gemini thorough models.

## Input

```
/so "Should we use Prisma or Drizzle ORM for our new TypeScript project?"
```

## Workflow

1. **Parse Arguments**
   - AI_SPEC: (empty/default)
   - QUESTION: "Should we use Prisma or Drizzle ORM for our new TypeScript project?"

2. **Pre-flight Evaluation**
   - Question is specific and comparative
   - May benefit from codebase context if there are existing patterns
   - Mode: `architect` (design decision)

3. **Invoke /complete-prompt**
   ```
   Skill tool: complete-prompt
   Args: "architect"
   ```
   Output: `.prompts/20260205-150132-architect.xml`

4. **Spawn Coordinator**
   Two parallel sub-agents for Codex and Gemini thorough models.

5. **Raw Responses**

```
## CODEX (gpt-5.2-codex) ##
────────────────────────────────────────
For a new TypeScript project, I'd recommend **Drizzle** over Prisma for these reasons:

**Drizzle advantages:**
- Type-safe queries that mirror SQL (no DSL to learn)
- Lightweight: ~7KB vs Prisma's ~300KB engine
- No codegen step — types are derived from schema
- Better serverless performance (no cold start penalty)

**When to choose Prisma instead:**
- Team familiarity with Prisma
- Need for Prisma Studio GUI
- Complex migration workflows

**My recommendation:** Drizzle for new greenfield projects, Prisma if you need
its ecosystem tools or have existing team expertise.
────────────────────────────────────────
📁 Saved: .responses/codex-gpt-5.2-codex-20260205-150135.txt

## GEMINI (gemini-3-pro-preview) ##
────────────────────────────────────────
Both are excellent choices, but they serve different philosophies:

**Prisma:**
- ✓ Mature ecosystem, excellent documentation
- ✓ Visual schema management (Prisma Studio)
- ✓ Strong migration tooling
- ✗ Larger bundle, slower cold starts
- ✗ Custom DSL (Prisma Client) has learning curve

**Drizzle:**
- ✓ SQL-like syntax, minimal abstraction
- ✓ Tiny bundle, fast cold starts
- ✓ No codegen required
- ✗ Younger ecosystem, fewer tutorials
- ✗ Migration tooling less polished

**Verdict:** For serverless or edge functions, Drizzle wins on performance.
For larger team projects with junior developers, Prisma's tooling helps.
────────────────────────────────────────
📁 Saved: .responses/gemini-gemini-3-pro-preview-20260205-150138.txt
```

6. **Verification**
   - 2 responses received ✓
   - Both responses are substantial (>100 chars) ✓
   - No truncation ✓

7. **Synthesis**

```
## CONSENSUS: CODEX, GEMINI ##
────────────────────────────────────────
Both AIs agree on the core tradeoffs:
- Drizzle: Better for serverless, smaller bundle, SQL-like syntax
- Prisma: Better tooling, more mature ecosystem, steeper learning curve

Key difference in recommendation:
- Codex leans toward Drizzle for greenfield projects
- Gemini emphasizes team composition as the deciding factor
────────────────────────────────────────

## MY SYNTHESIS ##
────────────────────────────────────────
**Recommendation:** Given your TypeScript project is new (greenfield):

1. **Choose Drizzle if:** Deploying to serverless/edge, small team,
   team is comfortable with SQL

2. **Choose Prisma if:** Need visual tools, larger team with mixed
   experience levels, complex migration needs

For a typical new project with an experienced team, I'd lean toward Drizzle
for the performance benefits and simpler mental model. The ecosystem gap is
closing quickly.
────────────────────────────────────────
```

## Key Points

- Default mode gets two perspectives to triangulate recommendations
- Synthesis highlights both consensus and divergence
- The merging rules identified that responses were similar in structure, so they were grouped under "CONSENSUS"
- My synthesis adds Claude's perspective as a tiebreaker
