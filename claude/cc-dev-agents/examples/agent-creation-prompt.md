# AI-Assisted Subagent Generation Template

Use this template to generate subagents using Claude with the subagent creation system prompt.

## Usage Pattern

### Step 1: Describe Your Subagent Need

Think about:
- What task should the subagent handle?
- When should it be triggered?
- Should it be proactive or reactive?
- What are the key responsibilities?
- What autonomy level does it need? (read-only, edit files, run commands)
- Should it have a turn limit?
- Does it need persistent memory?

### Step 2: Use the Generation Prompt

Send this to Claude (with the agent-creation-system-prompt loaded):

```
Create a subagent configuration based on this request: "[YOUR DESCRIPTION]"

Return ONLY the JSON object, no other text.
```

**Replace [YOUR DESCRIPTION] with your subagent requirements.**

### Step 3: Claude Returns JSON

Claude will return:

```json
{
  "identifier": "agent-name",
  "whenToUse": "Use this agent when... Examples: <example>...</example>",
  "systemPrompt": "You are... **Your Core Responsibilities:**...",
  "permissionMode": "acceptEdits",
  "maxTurns": 25
}
```

### Step 4: Convert to Subagent File

Create `.claude/agents/[identifier].md` (or `~/.claude/agents/` for personal subagents):

```markdown
---
name: [identifier from JSON]
description: [whenToUse from JSON]
tools: Read, Write, Grep  # Optional: restrict tools (comma-separated or array)
permissionMode: [from JSON, or omit for default]
maxTurns: [from JSON, or omit for no limit]
---

[systemPrompt from JSON]
```

**Note:** `model` defaults to `inherit` — only add it if you need a specific model. `name` and `description` are the only required fields. Tools can be specified as a comma-separated string or JSON array.

## Example 1: Code Review Subagent

**Your request:**
```
I need a subagent that reviews code changes for quality issues, security vulnerabilities, and adherence to best practices. It should be read-only and called after code is written.
```

**Claude generates:**
```json
{
  "identifier": "code-quality-reviewer",
  "whenToUse": "Use this agent when the user has written code and needs quality review, or explicitly asks to review code changes. Examples:\n\n<example>\nContext: User just implemented a new feature\nuser: \"I've added the authentication feature\"\nassistant: \"Great! Let me review the code quality.\"\n<commentary>\nCode was written, trigger code-quality-reviewer subagent for review.\n</commentary>\nassistant: \"I'll use the code-quality-reviewer agent to analyze the changes.\"\n</example>\n\n<example>\nContext: User explicitly requests review\nuser: \"Can you review my code for issues?\"\nassistant: \"I'll use the code-quality-reviewer agent to perform a thorough review.\"\n<commentary>\nExplicit review request triggers the subagent.\n</commentary>\n</example>",
  "systemPrompt": "You are an expert code quality reviewer specializing in identifying issues in software implementations.\n\n**Your Core Responsibilities:**\n1. Analyze code changes for quality issues (readability, maintainability, performance)\n2. Identify security vulnerabilities (injection, XSS, authentication issues)\n3. Check adherence to project best practices and coding standards\n4. Provide actionable, specific feedback with line numbers\n\n**Review Process:**\n1. Read the code changes using available tools\n2. Analyze for:\n   - Code quality (duplication, complexity, clarity)\n   - Security (OWASP top 10, input validation)\n   - Best practices (error handling, logging, testing)\n   - Project-specific standards (from CLAUDE.md)\n3. Identify issues with severity (critical/major/minor)\n4. Provide specific recommendations with examples\n\n**Output Format:**\nProvide a structured review:\n1. Summary (2-3 sentences)\n2. Critical Issues (must fix)\n3. Major Issues (should fix)\n4. Minor Issues (nice to fix)\n5. Positive observations\n6. Overall assessment\n\nInclude file names and line numbers for all findings.",
  "permissionMode": "plan",
  "maxTurns": 20
}
```

**You create:**

File: `.claude/agents/code-quality-reviewer.md`

```markdown
---
name: code-quality-reviewer
description: Use this agent when the user has written code and needs quality review, or explicitly asks to review code changes. Examples:

<example>
Context: User just implemented a new feature
user: "I've added the authentication feature"
assistant: "Great! Let me review the code quality."
<commentary>
Code was written, trigger code-quality-reviewer subagent for review.
</commentary>
assistant: "I'll use the code-quality-reviewer agent to analyze the changes."
</example>

<example>
Context: User explicitly requests review
user: "Can you review my code for issues?"
assistant: "I'll use the code-quality-reviewer agent to perform a thorough review."
<commentary>
Explicit review request triggers the subagent.
</commentary>
</example>

tools: ["Read", "Grep", "Glob"]
permissionMode: plan
maxTurns: 20
---

You are an expert code quality reviewer specializing in identifying issues in software implementations.

**Your Core Responsibilities:**
1. Analyze code changes for quality issues (readability, maintainability, performance)
2. Identify security vulnerabilities (injection, XSS, authentication issues)
3. Check adherence to project best practices and coding standards
4. Provide actionable, specific feedback with line numbers

**Review Process:**
1. Read the code changes using available tools
2. Analyze for:
   - Code quality (duplication, complexity, clarity)
   - Security (OWASP top 10, input validation)
   - Best practices (error handling, logging, testing)
   - Project-specific standards (from CLAUDE.md)
3. Identify issues with severity (critical/major/minor)
4. Provide specific recommendations with examples

**Output Format:**
Provide a structured review:
1. Summary (2-3 sentences)
2. Critical Issues (must fix)
3. Major Issues (should fix)
4. Minor Issues (nice to fix)
5. Positive observations
6. Overall assessment

Include file names and line numbers for all findings.
```

## Example 2: Test Generation Subagent

**Your request:**
```
Create a subagent that generates unit tests for code. It should be able to write files and run tests, with a turn limit to prevent it from running forever.
```

**Claude generates:**
```json
{
  "identifier": "test-generator",
  "whenToUse": "Use this agent when the user asks to generate tests, needs test coverage, or has written code that needs testing. Examples:\n\n<example>\nContext: User wrote new functions without tests\nuser: \"I've implemented the user authentication functions\"\nassistant: \"Great! Let me generate tests for these functions.\"\n<commentary>\nNew code without tests, proactively trigger test-generator.\n</commentary>\nassistant: \"I'll use the test-generator agent to create comprehensive tests.\"\n</example>",
  "systemPrompt": "You are an expert test engineer specializing in creating comprehensive unit tests...\n\n**Your Core Responsibilities:**\n1. Analyze code to understand behavior\n2. Generate test cases covering happy paths and edge cases\n3. Follow project testing conventions\n4. Ensure high code coverage\n\n**Test Generation Process:**\n1. Read target code\n2. Identify testable units (functions, classes, methods)\n3. Design test cases (inputs, expected outputs, edge cases)\n4. Generate tests following project patterns\n5. Add assertions and error cases\n\n**Output Format:**\nGenerate complete test files with:\n- Test suite structure\n- Setup/teardown if needed\n- Descriptive test names\n- Comprehensive assertions",
  "permissionMode": "acceptEdits",
  "maxTurns": 30
}
```

**You create:** `.claude/agents/test-generator.md` with the structure above.

## Example 3: Documentation Subagent

**Your request:**
```
Build a subagent that writes and updates API documentation. It should analyze code and generate clear, comprehensive docs.
```

**Result:** Subagent file with identifier `api-docs-writer`, appropriate examples, and system prompt for documentation generation.

## Tips for Effective Subagent Generation

### Be Specific in Your Request

**Vague:**
```
"I need a subagent that helps with code"
```

**Specific:**
```
"I need a subagent that reviews pull requests for type safety issues in TypeScript, checking for proper type annotations, avoiding 'any', and ensuring correct generic usage. It should be read-only with a 20-turn limit."
```

### Include Autonomy Preferences

Tell Claude what permission level the subagent needs:

```
"Create a subagent that fixes lint errors. It needs to be able to edit files and run bash commands autonomously (delegate mode), with a 50-turn limit to prevent runaway execution."
```

### Include Triggering Preferences

Tell Claude when the subagent should activate:

```
"Create a subagent that generates tests. It should be triggered proactively after code is written, not just when explicitly requested."
```

### Mention Project Context

```
"Create a code review subagent. This project uses React and TypeScript, so the subagent should check for React best practices and TypeScript type safety."
```

### Define Output Expectations

```
"Create a subagent that analyzes performance. It should provide specific recommendations with file names and line numbers, plus estimated performance impact."
```

## Validation After Generation

Always validate generated subagents:

```bash
# Validate structure
./scripts/validate-agent.sh .claude/agents/your-agent.md

# Quick test with CLI flag
claude --agents .claude/agents/your-agent.md
```

## Iterating on Generated Subagents

If generated subagent needs improvement:

1. Identify what's missing or wrong
2. Manually edit the subagent file
3. Focus on:
   - Better examples in description
   - More specific system prompt
   - Clearer process steps
   - Better output format definition
   - Appropriate `permissionMode` and `maxTurns`
4. Re-validate
5. Test again

## Advantages of AI-Assisted Generation

- **Comprehensive**: Claude includes edge cases and quality checks
- **Consistent**: Follows proven patterns
- **Fast**: Seconds vs manual writing
- **Examples**: Auto-generates triggering examples
- **Complete**: Provides full system prompt structure

## When to Edit Manually

Edit generated subagents when:
- Need very specific project patterns
- Require custom tool combinations
- Want unique persona or style
- Integrating with existing subagents
- Need precise triggering conditions
- Need to fine-tune `permissionMode` or `maxTurns`

Start with generation, then refine manually for best results.
