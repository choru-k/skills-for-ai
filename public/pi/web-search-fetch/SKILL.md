---
name: web-search-fetch
description: Search the web and fetch readable web content in Pi. Use when external docs, API references, changelogs, or issue threads are needed.
user-invocable: true
---

# Web Search + Fetch

Use this capability when you need external references beyond the local repository.

## Tools

- `web_search`
  - Search queries on the web.
  - Good for finding authoritative docs and candidate sources quickly.

- `fetch`
  - Fetch and convert pages into readable text.
  - Good for validating and citing concrete details from the selected URLs.

## Recommended flow

1. Run `web_search` with focused queries.
2. Pick high-signal sources (official docs, standards, maintainers).
3. Run `fetch` on selected URLs.
4. Summarize findings and cite URLs.
