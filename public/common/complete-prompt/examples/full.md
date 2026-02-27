# Full Mode Examples

## Example 1: Feature Implementation (User Auth)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1">

<summary>
Implementing a JWT-based authentication system for the 'api-service'. We have set up the basic Express server and connected to MongoDB, but need to implement the login route and JWT signing logic.
</summary>

<system-role>
You are a backend engineer specializing in Node.js and security.
- Prioritize security best practices (OWASP)
- Ensure proper error handling and logging
- Use async/await for all database operations
</system-role>

<success-criteria>
<criterion>User can login with valid credentials and receive a JWT</criterion>
<criterion>Invalid credentials return 401 Unauthorized</criterion>
<criterion>Passwords are hashed using bcrypt before comparison</criterion>
</success-criteria>

<non-goals>
<item>Password reset functionality (future task)</item>
<item>OAuth/Social login</item>
</non-goals>

<background>
<project>api-service</project>
<stack>Node.js, Express, MongoDB, Mongoose, JSON Web Tokens</stack>
</background>

<task>
<description>Implement the POST /auth/login endpoint</description>
<original-request>"Create the login endpoint that validates email/password and returns a token"</original-request>
</task>

<files>
<file path="src/routes/auth.js" purpose="Auth routes definition">
<![CDATA[
const express = require('express');
const router = express.Router();
const User = require('../models/User');

// POST /auth/register is already done
router.post('/register', async (req, res) => { ... });

// TODO: Implement login
router.post('/login', async (req, res) => {
  // Logic goes here
});

module.exports = router;
]]>
</file>
<file path="src/models/User.js" purpose="User schema">
<![CDATA[
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const UserSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  passwordHash: { type: String, required: true }
});
// ... schema methods ...
]]>
</file>
</files>

<decisions>
<decision choice="bcrypt" rationale="Standard for password hashing in Node">
<rejected>md5 - insecure</rejected>
</decision>
<decision choice="1 hour expiration" rationale="Short lived tokens for security, refresh token later">
</decision>
</decisions>

<constraints>
<constraint>Must use environment variables for JWT_SECRET</constraint>
</constraints>

<status>
<completed>
<item>User model created</item>
<item>Registration endpoint working</item>
</completed>
<in-progress>
<item>Login endpoint</item>
</in-progress>
</status>

<next-steps>
1. Import `jsonwebtoken` and `bcrypt` in auth.js
2. Implement the login logic: find user, compare password, sign token
3. Return the token in the response body
</next-steps>

<what-is-missing>
Verify if we have a standard error response format.
</what-is-missing>

</context-handoff>
```

## Example 2: Refactoring (Monolithic Function)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1">

<summary>
Refactoring a large `processOrder` function in `OrderService.ts` to improve testability. The function currently handles validation, payment, and inventory updates all in one 200-line block.
</summary>

<system-role>
You are a Clean Code advocate.
- Break down complex logic into small, pure functions where possible
- Maintain current behavior exactly (refactoring, not rewriting)
- Apply Dependency Injection if helpful
</system-role>

<success-criteria>
<criterion>`processOrder` is under 50 lines</criterion>
<criterion>Logic is split into `validateOrder`, `processPayment`, `updateInventory`</criterion>
<criterion>All existing tests pass</criterion>
</success-criteria>

<task>
<description>Extract sub-functions from processOrder</description>
</task>

<files>
<file path="src/services/OrderService.ts">
<![CDATA[
export class OrderService {
  async processOrder(order: Order) {
    // ... 200 lines of mixed logic ...
    // validation checks
    // stripe api call
    // database update
    // email notification
  }
}
]]>
</file>
</files>

<decisions>
<decision choice="Private helper methods" rationale="Keep them within the class for now to avoid creating too many files at once">
</decision>
</decisions>

<status>
<completed>
<item>Identified the logical blocks</item>
</completed>
<in-progress>
<item>Extracting `validateOrder` method</item>
</in-progress>
</status>

<next-steps>
Extract the validation logic into a private method `validateOrder(order: Order): void`.
Then proceed to extract payment logic.
</next-steps>

</context-handoff>
```

## Example 3: Config Migration (JSON to YAML)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<context-handoff version="1.1">

<summary>
Migrating the application configuration from `config.json` to `config.yaml` to support comments and better readability. Need to update the config loader and convert the existing file.
</summary>

<system-role>
You are a DevOps engineer focusing on maintainability.
</system-role>

<background>
<project>cli-tool</project>
<stack>Python, PyYAML</stack>
</background>

<task>
<description>Switch configuration format to YAML</description>
</task>

<files>
<file path="src/config_loader.py">
<![CDATA[
import json

def load_config(path='config.json'):
    with open(path, 'r') as f:
        return json.load(f)
]]>
</file>
<file path="config.json">
<![CDATA[
{
  "timeout": 30,
  "retries": 3,
  "endpoints": ["api1", "api2"]
}
]]>
</file>
</files>

<constraints>
<constraint>Must handle missing file gracefully</constraint>
<constraint>Backward compatibility: check for json if yaml not found (optional but good)</constraint>
</constraints>

<status>
<in-progress>
<item>Updating loader code</item>
</in-progress>
</status>

<next-steps>
1. Install PyYAML
2. Update `load_config` to read .yaml
3. Convert `config.json` content to `config.yaml`
</next-steps>

</context-handoff>
```
