---
name: skill-commons
description: Shared contract nodes reused by multiple skills (routing, delegation, lifecycle, and output conventions).
user-invocable: false
disable-model-invocation: true
allowed-tools: Read
---

# Skill Commons

Shared, reusable graph contracts for multi-skill consistency.

This skill is reference-only. Other skills link to these contract nodes.

## Progressive Loading

1. `graph/index.md`
2. `graph/mocs/contracts.md`
3. required contract node(s)

## Purpose

- reduce duplicated policy text
- keep cross-skill behavior consistent
- provide one place to update shared contracts
