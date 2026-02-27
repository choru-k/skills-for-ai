# Architect Mode Examples

## Example 1: Notifications System Design

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="architect">

<summary>Designing a centralized notification service to handle email, SMS, and push notifications.</summary>

<system-role>
System Architect.
- Design for high throughput and reliability
- Ensure vendor abstraction (Twilio, SendGrid, etc.)
</system-role>

<problem>
<description>Currently, every service sends emails directly using SMTP. No tracking, no unified preferences, hard to switch providers.</description>
<requirements>
<requirement priority="must">Support Email and SMS initially</requirement>
<requirement priority="must">User preference management (opt-out)</requirement>
<requirement priority="should">Rate limiting per user</requirement>
</requirements>
</problem>

<current-architecture>
<description>Ad-hoc calls to SendGrid from Monolith, Billing Service, and Auth Service.</description>
</current-architecture>

<proposed-design>
<description>Async worker-based system processing events from a queue.</description>
<components>
<component name="Notification API">Receives send requests, checks prefs, pushes to queue</component>
<component name="Queue (SQS)">Buffers messages</component>
<component name="Workers">Process messages, call vendor APIs</component>
</components>
<diagram><![CDATA[
[Service A] -> [Notification API] -> [SQS] -> [Worker] -> [SendGrid/Twilio]
                     ^
                     |
              [DB: Preferences]
]]></diagram>
</proposed-design>

<trade-offs>
<option name="Sync vs Async">
<pros>Async prevents blocking the caller, handles spikes better.</pros>
<cons>Harder to return immediate success/fail status to caller.</cons>
</option>
</trade-offs>

<next-steps>
Review the queue selection (SQS vs RabbitMQ) and database schema for preferences.
</next-steps>

</context-handoff>
```

## Example 2: Plugin Architecture

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="architect">

<summary>Designing a plugin system for a CLI tool to allow 3rd party commands.</summary>

<system-role>
Library Author.
</system-role>

<success-criteria>
<criterion>Plugins can be installed via npm</criterion>
<criterion>Core tool automatically discovers installed plugins</criterion>
</success-criteria>

<proposed-design>
<description>Convention over configuration. Plugins named `tool-plugin-*` are auto-loaded.</description>
</proposed-design>

<open-questions>
<question>How to handle conflicting command names?</question>
<question>Should we sandbox plugins for security?</question>
</open-questions>

<next-steps>
Decide on the discovery mechanism (scanning node_modules vs config file).
</next-steps>

</context-handoff>
```

## Example 3: Analytics Pipeline

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="architect">

<summary>Moving from direct DB writes to an event-based analytics pipeline.</summary>

<problem>
<description>Writing analytics directly to the primary DB is causing lock contention and slowing down user requests.</description>
</problem>

<proposed-design>
<description>Emit events to Kinesis, process with Lambda, store in Snowflake.</description>
<diagram><![CDATA[
[App] -> [Kinesis Firehose] -> [S3 (Raw)] -> [Snowpipe] -> [Snowflake]
]]></diagram>
</proposed-design>

<constraints>
<constraint>Must be near real-time (latency < 5 mins)</constraint>
<constraint>Cost effective for 1M events/day</constraint>
</constraints>

<next-steps>
Validate if Kinesis Firehose buffering limits meet the 5 min latency requirement.
</next-steps>

</context-handoff>
```
