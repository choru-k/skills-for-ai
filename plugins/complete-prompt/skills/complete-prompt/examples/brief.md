# Brief Mode Examples

## Example 1: UI Tweak

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="brief">

<summary>Fixing alignment on the navbar login button.</summary>

<system-role>Frontend dev, fix CSS issues.</system-role>

<task>Add margin-left to the login button so it doesn't touch the search bar.</task>

<files>
<file path="src/components/Navbar.css" purpose="Styles">
<![CDATA[
.search-bar { width: 200px; }
.login-btn { 
  /* Needs margin here */
  background: blue; 
}
]]>
</file>
</files>

<status>Identified the issue, just need to apply the fix.</status>

<next-steps>Add `margin-left: 16px;` to `.login-btn` class.</next-steps>

<what-is-missing>None</what-is-missing>

</context-handoff>
```

## Example 2: Quick Fix (Log Message)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="brief">

<summary>Correcting a typo in the startup log message.</summary>

<system-role>Quick code fix.</system-role>

<task>Change "Sever started" to "Server started".</task>

<files>
<file path="server.go">
<![CDATA[
func main() {
    // ... setup ...
    log.Println("Sever started on port 8080") 
}
]]>
</file>
</files>

<status>Ready to edit.</status>

<next-steps>Fix the typo.</next-steps>

<what-is-missing>None</what-is-missing>

</context-handoff>
```

## Example 3: Dependency Update

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1" mode="brief">

<summary>Updating `requests` library to patch a security vulnerability.</summary>

<system-role>Maintenance.</system-role>

<task>Bump `requests` from 2.25.1 to 2.31.0 in requirements.txt.</task>

<files>
<file path="requirements.txt">
<![CDATA[
flask==2.0.1
requests==2.25.1
]]>
</file>
</files>

<status>Pending update.</status>

<next-steps>Update the version number.</next-steps>

<what-is-missing>None</what-is-missing>

</context-handoff>
```
