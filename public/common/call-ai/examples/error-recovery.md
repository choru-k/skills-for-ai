# Error Recovery Examples

How to handle and recover from common `/call-ai` failures.

## Diagnostic Commands

### Check Recent Errors
```bash
# List recent error files
ls -lt .responses/*.err 2>/dev/null | head -5

# View specific error
cat .responses/codex-gpt-5.2-codex-20260205-143022.txt.err
```

### Check Metrics
```bash
# View last few metrics entries
tail -5 .responses/metrics.csv

# Parse JSON metrics
cat .responses/*.metrics.json | jq -s 'sort_by(.timestamp) | last'
```

### Validate Response Quality
```bash
# Run validation script
scripts/validate-response.sh \
  .responses/codex-gpt-5.2-codex-20260205-143022.txt
```

---

## Common Errors & Recovery

### 1. Rate Limit (429)

**Symptom:**
```
⚠️ FAILED after 3 retries: Rate limit exceeded
```

**Recovery:**
```bash
# Wait 60 seconds
sleep 60

# Retry single AI
/call-ai codex "your prompt"

# Or use a different provider
/call-ai gemini "your prompt"
```

**Prevention:**
- Space out `:all` invocations by 2-3 minutes
- Use default (2 AIs) for routine queries

---

### 2. Authentication Error (401/403)

**Symptom:**
```
⚠️ FAILED: Unauthorized - invalid API key
```

**Diagnosis:**
```bash
# Check if key exists
security find-generic-password -s "codex-api-key" -w 2>/dev/null && echo "Key exists" || echo "Key missing"
```

**Recovery:**
```bash
# Re-add the API key
security add-generic-password -s "codex-api-key" -a "$(whoami)" -w "your-api-key-here"

# Verify
security find-generic-password -s "codex-api-key" -w
```

---

### 3. Timeout

**Symptom:**
```
⚠️ FAILED after 3 retries: Connection timeout
```

**Diagnosis:**
```bash
# Check network
ping -c 3 api.openai.com

# Check if VPN is required/blocking
curl -s https://api.openai.com/v1/models | head -c 100
```

**Recovery:**
- Check VPN status
- Try a different network
- Wait and retry (API may be overloaded)

---

### 4. Missing CLI

**Symptom:**
```
✗ codex CLI not installed
```

**Recovery:**
```bash
# Install Codex CLI
brew install codex

# Install Gemini CLI
pip install gemini-cli

# Verify
which codex gemini claude
```

---

### 5. Context Length Exceeded

**Symptom:**
```
⚠️ FAILED: Maximum context length exceeded
```

**Recovery:**
```bash
# Check prompt size
wc -c < your-prompt.xml
# If > 100K, need to reduce

# Use brief mode for context generation
/so brief "shorter question"

# Or split into multiple queries
```

---

### 6. Empty/Truncated Response

**Symptom:**
```
⚠️ WARNING: Suspiciously short response (<50 chars)
```

**Diagnosis:**
```bash
# Check the response file
cat .responses/gemini-*-20260205-*.txt

# Check for errors
cat .responses/gemini-*-20260205-*.txt.err
```

**Recovery:**
- Simplify the prompt
- Try a different model
- Check if prompt contains problematic content

---

## Partial Failure Strategy

When `:all` returns partial results:

### Option 1: Proceed with Available
If 4/6 AIs responded, you likely have enough signal:
```
Codex thorough: ✓
Codex fast: ✓
Gemini thorough: ✗ (rate limited)
Gemini fast: ✓
Claude thorough: ✓
Claude fast: ✗ (timeout)
```
**Action:** Synthesize from 4 responses; note incomplete data.

### Option 2: Retry Failed Only
```
/call-ai gemini "your prompt"  # Retry Gemini
```

### Option 3: Use Default Mode
Fall back to 2-AI mode for reliability:
```
/call-ai "your prompt"  # Codex + Gemini thorough only
```

---

## Error Log Analysis

Track error patterns over time:

```bash
# Count errors by type in metrics.csv
awk -F',' 'NR>1 && $4=="failed" {print $8}' \
  .responses/metrics.csv | sort | uniq -c | sort -rn

# Find providers with highest failure rates
awk -F',' 'NR>1 {total[$2]++; if($4=="failed") failed[$2]++} END {for(ai in total) print ai, failed[ai]/total[ai]*100"%"}' \
  .responses/metrics.csv
```
