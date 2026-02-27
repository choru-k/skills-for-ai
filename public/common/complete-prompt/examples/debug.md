# Debug Mode Examples

## Example 1: JavaScript Runtime Error (Undefined)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="debug">

<summary>Crash in `UserProfile` component when user address is missing.</summary>

<system-role>
You are debugging a React frontend crash.
- Check for optional chaining opportunities
- Verify API response shape matches expectations
</system-role>

<success-criteria>
<criterion>Component renders without crashing when address is null</criterion>
</success-criteria>

<error>
<message><![CDATA[
Uncaught TypeError: Cannot read properties of undefined (reading 'street')
    at UserProfile (UserProfile.js:15)
]]></message>
<when>When loading a user who hasn't filled out their profile yet.</when>
<where>UserProfile.js line 15</where>
</error>

<reproduction>
<steps>
<step>Login as 'newuser'</step>
<step>Navigate to /profile</step>
</steps>
<expected>Profile page loads with empty address fields</expected>
<actual>White screen / React error boundary triggers</actual>
</reproduction>

<files>
<file path="src/components/UserProfile.js" purpose="Component causing crash">
<![CDATA[
const UserProfile = ({ user }) => {
  return (
    <div>
      <h1>{user.name}</h1>
      <p>Address: {user.address.street}</p> {/* Error here */}
    </div>
  );
};
]]>
</file>
</files>

<hypotheses>
<hypothesis status="untested">User object has no `address` property for new users</hypothesis>
</hypotheses>

<next-steps>
Inspect the `user` object structure and add a check or optional chaining `user.address?.street`.
</next-steps>

<what-is-missing>
Sample JSON payload for a problematic user.
</what-is-missing>

</context-handoff>
```

## Example 2: Database Connection Timeout

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="debug">

<summary>Intermittent DB connection timeouts in production.</summary>

<system-role>
Backend SRE.
</system-role>

<error>
<message><![CDATA[
SequelizeConnectionError: connect ETIMEDOUT 10.0.0.5:5432
]]></message>
<when>During high traffic spikes (Monday mornings)</when>
<where>Database connection pool initialization</where>
</error>

<context>
<recent-changes>Increased max pool size from 10 to 50 last week</recent-changes>
<environment>AWS RDS, Node.js service running on Fargate</environment>
</context>

<files>
<file path="src/db.js">
<![CDATA[
const sequelize = new Sequelize(url, {
  pool: {
    max: 50,
    min: 0,
    acquire: 30000,
    idle: 10000
  }
});
]]>
</file>
</files>

<hypotheses>
<hypothesis status="untested">RDS instance max_connections limit reached</hypothesis>
<hypothesis status="untested">Network latency between Fargate and RDS</hypothesis>
</hypotheses>

<next-steps>
Check CloudWatch metrics for RDS connection count.
Review `max` pool size vs available database connections.
</next-steps>

</context-handoff>
```

## Example 3: Build Failure (Missing Type)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="debug">

<summary>TypeScript build failing after adding `PaymentProcessor` interface.</summary>

<system-role>
TypeScript expert.
</system-role>

<error>
<message><![CDATA[
src/services/StripeService.ts:12:7 - error TS2420: Class 'StripeService' incorrectly implements interface 'PaymentProcessor'.
  Property 'refund' is missing in type 'StripeService' but required in type 'PaymentProcessor'.
]]></message>
<when>Running `npm run build`</when>
<where>src/services/StripeService.ts</where>
</error>

<files>
<file path="src/interfaces/PaymentProcessor.ts">
<![CDATA[
export interface PaymentProcessor {
  charge(amount: number): Promise<void>;
  refund(id: string): Promise<void>; // Added this recently
}
]]>
</file>
<file path="src/services/StripeService.ts">
<![CDATA[
export class StripeService implements PaymentProcessor {
  async charge(amount: number) {
    // ... implementation
  }
  // Missing refund method
}
]]>
</file>
</files>

<attempted-fixes>
<fix result="did not work">Restarted TS server</fix>
</attempted-fixes>

<next-steps>
Implement the `refund` method in `StripeService.ts`.
</next-steps>

</context-handoff>
```
