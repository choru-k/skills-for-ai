# Diff Mode Examples

## Example 1: Bug Fix (Off-by-one)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="diff">

<summary>Fixing an off-by-one error in pagination logic.</summary>

<system-role>Code Reviewer.</system-role>

<change-summary>
<goal>Ensure the last page of results is reachable.</goal>
<scope>PaginationHelper.js</scope>
</change-summary>

<changes>
<file path="src/utils/PaginationHelper.js">
<before><![CDATA[
export const getTotalPages = (total, limit) => {
  return Math.floor(total / limit);
};
]]></before>
<after><![CDATA[
export const getTotalPages = (total, limit) => {
  return Math.ceil(total / limit);
};
]]></after>
<rationale>Floor was truncating the last partial page.</rationale>
</file>
</changes>

<testing>
<tested>Unit tests updated to check edge cases (total % limit != 0).</tested>
</testing>

<next-steps>Approve if tests pass.</next-steps>

</context-handoff>
```

## Example 2: API Endpoint Addition

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="diff">

<summary>Adding `GET /api/health` endpoint.</summary>

<system-role>Reviewer.</system-role>

<changes>
<file path="src/app.js">
<before><![CDATA[
app.use('/api', apiRoutes);
]]></before>
<after><![CDATA[
app.get('/api/health', (req, res) => res.json({ status: 'ok' }));
app.use('/api', apiRoutes);
]]></after>
<rationale>Load balancers need a health check endpoint.</rationale>
</file>
</changes>

<concerns>
<concern>Should this be authenticated or public? (Assuming public for LB)</concern>
</concerns>

<next-steps>Verify security policy allows public health checks.</next-steps>

</context-handoff>
```

## Example 3: Config Cleanup

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="diff">

<summary>Removing unused configuration keys.</summary>

<system-role>Reviewer.</system-role>

<changes>
<file path="config.default.js">
<before><![CDATA[
module.exports = {
  port: 3000,
  legacy_mode: true, // DEPRECATED
  theme: 'dark'
};
]]></before>
<after><![CDATA[
module.exports = {
  port: 3000,
  theme: 'dark'
};
]]></after>
<rationale>Legacy mode code was removed in PR #123, cleaning up config now.</rationale>
</file>
</changes>

<testing>
<tested>Booted app locally, no errors.</tested>
</testing>

<next-steps>Merge.</next-steps>

</context-handoff>
```
