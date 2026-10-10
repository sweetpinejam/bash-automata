---
name: "Agent Guard Bypass"
about: "Report a vulnerability where hostile shell commands bypass the AST or dry-run gate"
title: "[GUARD BYPASS] <Command Pattern>"
labels: ["security", "guard", "vulnerability"]
---

### 1. Hostile Payload
Provide the exact command payload:
```bash
<payload here>
```

### 2. AST / Linter Bypass Mechanism
Explain why `bashlex` or ShellCheck failed to intercept this pattern.

### 3. Proposed Resilient Pattern
How the AST parser or token rule should be hardened.
