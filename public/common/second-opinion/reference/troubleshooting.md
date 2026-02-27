# Troubleshooting

Error handling and recovery for `/second-opinion`.

## Error Reference

| Error | Cause | Recovery |
|-------|-------|----------|
| `/complete-prompt` fails | Template error, context issue | Report error, abort workflow |
| Single AI fails | API timeout, rate limit | See partial results policy |
| All AIs fail | Network outage, key issues | Show troubleshooting steps |
| Empty/short response | API error, truncation | Flag in verification step |

## Partial Results Policy

When some (but not all) AI calls fail:

1. **Return successful responses** with full formatting
2. **Log failures explicitly** in the output:
   ```
   ## GEMINI (gemini-3-pro-preview) ##
   ────────────────────────────────────────
   ⚠️ FAILED: Connection timeout after 3 retries
   ────────────────────────────────────────
   ```
3. **Adjust synthesis** to note incomplete data
4. **Offer retry option** for failed AIs only

## Never Fail Silently

Every error must be visible in output. Include:
- Which step failed
- Error message/code
- Suggested troubleshooting

## Common Issues

| Symptom | Check |
|---------|-------|
| All AIs timeout | Network connectivity, VPN |
| 401/403 errors | API keys in Keychain (`security find-generic-password`) |
| Empty responses | Prompt file exists and has content |
| Partial failures | Rate limits, retry with single AI |

## Debugging Commands

Check if prompts are being generated:
```bash
ls .prompts/*.xml 2>/dev/null | tail -1 || echo "No prompts yet"
```

Check for saved responses:
```bash
ls .responses/ 2>/dev/null | tail -5 || echo "No responses yet"
```

Verify API key exists:
```bash
security find-generic-password -a "$USER" -s "openai_api_key" -w 2>/dev/null && echo "OpenAI key found" || echo "OpenAI key missing"
```
