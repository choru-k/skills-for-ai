---
name: jira
description: Interact with Jira issues via CLI. View ticket details, list assigned issues, create new tickets. Use for "jira", "view ticket", "my jira issues", "create jira ticket".
user-invocable: true
allowed-tools: Bash, AskUserQuestion, Skill
---

# Jira Skill

Interact with Jira issues using the `jira` CLI tool.
Supports viewing, listing, and creating issues with integration to the `/work-ticket` skill.

## Prerequisites

Before running any `jira` command, retrieve the API token from Keychain:

```bash
export JIRA_API_TOKEN=$(security find-generic-password -s "clumio-jira-api-token" -w 2>/dev/null)
```

**Important:** Run this export in the same Bash invocation as the jira command:

```bash
export JIRA_API_TOKEN=$(security find-generic-password -s "clumio-jira-api-token" -w) && jira issue view CENG-XXXX --plain
```

If token retrieval fails, inform user to run `./setup_secrets.sh` or add the token manually to Keychain.

## Subcommand Routing

Parse the user's input to determine the subcommand:

| Pattern | Subcommand |
|---------|------------|
| `/jira` (no args) | `view` (extract ticket from git branch) |
| `/jira CENG-1234` | `view CENG-1234` |
| `/jira view [TICKET]` | `view` |
| `/jira list` | `list` |
| `/jira create` | `create` |

## Subcommand: view

Display details for a specific Jira ticket.

### 1. Get Ticket Number

If ticket not provided as argument, extract from current git branch:

```bash
git branch --show-current
```

Look for pattern `CENG-\d+` in the branch name (e.g., `feature/CENG-1234-description` → `CENG-1234`).

If no ticket found in branch name, use AskUserQuestion:
- Question: "What is the ticket number (e.g., CENG-1234)?"
- Header: "Ticket"

### 2. Fetch Ticket Details

```bash
jira issue view CENG-XXXX --plain --comments 3
```

This displays:
- Summary and status
- Assignee and reporter
- Description
- Last 3 comments

### 3. Offer Work-Ticket Integration

After displaying the ticket, ask if the user wants to create an Obsidian planning folder:

Use AskUserQuestion:
- Question: "Would you like to create an Obsidian planning folder for this ticket?"
- Header: "Plan"
- Options:
  - "Yes" - Invoke `/work-ticket` skill
  - "No" - End workflow

If yes, invoke the skill:
```
Skill: work-ticket
```

Pass the ticket number context so `/work-ticket` doesn't need to re-extract it.

## Subcommand: list

List Jira issues assigned to the current user.

### 1. Get Current User

```bash
jira me
```

### 2. List Assigned Issues

```bash
jira issue list -a$(jira me) --plain --columns key,summary,status,priority
```

### 3. Apply Filters (Optional)

If the user specifies filters in natural language, translate to JQL:

| User says | Filter |
|-----------|--------|
| "in progress" | `-s"In Progress"` |
| "high priority" | `-yHigh` or `-yCritical` |
| "open", "todo" | `-s"To Do"` |
| "done", "resolved" | `-s"Done"` |

Example with filter:
```bash
jira issue list -a$(jira me) -s"In Progress" --plain --columns key,summary,status,priority
```

## Subcommand: create

Create a new Jira issue interactively.

### 1. Gather Issue Details

Use AskUserQuestion for each field:

**Issue Type:**
- Question: "What type of issue is this?"
- Header: "Type"
- Options: "Story (Recommended)", "Bug", "Task", "Spike"

**Summary:**
- Question: "What is the issue summary/title?"
- Header: "Summary"
- (Free text input)

**Description:**
- Question: "Describe the issue (can be brief, will be expanded later):"
- Header: "Description"
- (Free text input)

**Priority:**
- Question: "What is the priority?"
- Header: "Priority"
- Options: "Critical", "High", "Medium", "Low"

### 2. Create the Issue

```bash
jira issue create -tStory -s"Issue summary here" -b"Description here" -yMedium -a$(jira me)
```

The `-a$(jira me)` flag assigns the issue to the current user by default.

Replace the type flag value based on selection:
- Story: `-tStory` (default)
- Bug: `-tBug`
- Task: `-tTask`
- Spike: `-tSpike` (or `-t"Spike"` if needed)

### 3. Add to Current Sprint

Always add the newly created ticket to the active sprint:

```bash
# Get active sprint ID
jira sprint list --state active --plain
```

Parse the sprint ID from the first result, then add the ticket:

```bash
jira sprint add <SPRINT_ID> <TICKET_KEY>
```

This ensures tickets are never left in backlog.

### 4. Report Created Ticket

Parse the output to get the new ticket key (e.g., `CENG-5678`).

Display the created ticket information to the user.

### 5. Offer Work-Ticket Integration

Use AskUserQuestion:
- Question: "Would you like to start planning this ticket in Obsidian?"
- Header: "Plan"
- Options:
  - "Yes" - Invoke `/work-ticket` skill
  - "No" - End workflow

If yes, invoke the skill:
```
Skill: work-ticket
```

Pass the new ticket number so the planning folder is created.

## Error Handling

If `jira` command fails:
1. Check if user is authenticated: `jira me`
2. If auth fails, inform user to run: `jira auth login`
3. If specific ticket not found, suggest checking the ticket key

## Quick Reference

| Command | Description |
|---------|-------------|
| `/jira` | View ticket from current branch |
| `/jira CENG-1234` | View specific ticket |
| `/jira view` | View ticket (prompts if needed) |
| `/jira list` | List my assigned issues |
| `/jira create` | Create new issue interactively |
