# Tactical Field Manual: The Bracket Duel (`[` vs `[[ ]]` & Conditional Logic)

## 1. Systems Mental Model: Command vs Keyword
Many developers assume `[` and `[[` are interchangeable syntax flavors. In reality, they belong to fundamentally different execution paradigms inside the Linux OS:

```
                  ┌───────────────────────────────┐
                  │    TEST EXECUTION PARADIGM    │
                  └───────────────┬───────────────┘
                                  │
          ┌───────────────────────┴───────────────────────┐
          ▼                                               ▼
 [ The POSIX Single Bracket '[' ]            [ The Bash Double Bracket '[[' ]
 - Actually an executable (/usr/bin/[)       - A shell compound KEYWORD
 - Arguments undergo Word Splitting & Globs  - Word Splitting is DISABLED
 - Logical operators: -a, -o (Fragile!)      - Logical operators: &&, ||, ( )
 - Globs & regex: NOT SUPPORTED              - Native Globs (==) & Regex (=~)
 - Crashes on empty/space variables          - Safe on empty/space variables
```

### Why `[` Crashes on Empty Strings
The single bracket `[` is a command. Like any command, its arguments undergo Step 6 of the Bash evaluation sequence: **Word Splitting**.
```bash
VAR=""
if [ $VAR = "production" ]; then ...
```
1. `$VAR` expands to an empty string.
2. Word splitting deletes the token because it contains no characters.
3. The shell executes `[` with arguments: `argv[0] = "["`, `argv[1] = "="`, `argv[2] = "production"`, `argv[3] = "]"`.
4. The `[` binary expects an argument before the `=` operator, but finds none!
5. It crashes with:
   ```
   [: =: unary operator expected
   ```

### Why `[[ ]]` Never Crashes
The double bracket `[[` is a **compound keyword**. When Bash parses `[[`, it temporarily **disables Word Splitting and Pathname Expansion** for all tokens inside the brackets:
```bash
VAR=""
if [[ $VAR == "production" ]]; then ...
```
Even if `$VAR` is unquoted and empty, Bash preserves the empty string token internally. It compares `""` to `"production"`, evaluates to `false`, and proceeds cleanly without crashing.

---

## 2. Syntax Comparison: Single `[` vs Double `[[ ]]`

| Feature | Legacy Single Bracket `[` | Modern Double Bracket `[[ ]]` |
| :--- | :--- | :--- |
| **Empty Variable Safety** | ❌ Crashes unless manually quoted `"$VAR"` | ✅ 100% Safe even if unquoted `$VAR` |
| **Whitespace in Variable** | ❌ Crashes (`too many arguments`) | ✅ 100% Safe |
| **Logical AND** | `[ $A = 1 -a $B = 2 ]` (Unspecified POSIX behavior) | `[[ $A == 1 && $B == 2 ]]` |
| **Logical OR** | `[ $A = 1 -o $B = 2 ]` (Unspecified POSIX behavior) | `[[ $A == 1 \|\| $B == 2 ]]` |
| **Grouping Parentheses** | `[ \( $A = 1 \) ]` (Requires escaping) | `[[ ( $A == 1 && $B == 2 ) ]]` |
| **Glob Pattern Matching** | ❌ Not supported | `[[ $FILE == *.log ]]` |
| **Regular Expressions** | ❌ Not supported | `[[ $STR =~ ^[0-9]+$ ]]` |
| **String Comparison** | `=` | `==` or `=` |

---

## 3. Pattern Matching and Regex Inside `[[ ]]`

### 1. Glob Matching (`==`)
You can use shell wildcards directly inside `[[ ]]`:
```bash
# Checks if BRANCH starts with 'release/' or 'hotfix/':
if [[ "$BRANCH" == release/* || "$BRANCH" == hotfix/* ]]; then
    echo "Release branch verified."
fi
```
> [!WARNING]
> Keep wildcards outside quotes!
> `[[ $BRANCH == release/* ]]` matches any branch starting with `release/`.
> `[[ $BRANCH == "release/*" ]]` looks for a literal asterisk character `*`!

### 2. Regular Expression Matching (`=~`)
```bash
# Validating a strictly positive integer:
if [[ "$REPLICAS" =~ ^[0-9]+$ ]]; then
    echo "Replicas is an integer."
fi
```

---

## 4. Architectural Diagram: Pre-Flight Deployment Policy Engine

```
[ CLI: ./validator.sh <TARGET_ENV> <DEPLOY_TIER> <REPLICAS> <BRANCH> ]
                                │
                                ▼
                     [ Parameter Sanitization ]
            - Assert $# >= 4
            - Strip whitespace: ${TARGET_ENV// /}
                                │
                                ▼
                   [ Guard 1: Missing Env ]
       [[ -z "${TARGET_ENV// /}" ]] -> REJECTED: MISSING_TARGET_ENV (exit 2)
                                │
                                ▼
                   [ Guard 2: Numeric Replicas ]
       [[ ! "$REPLICAS" =~ ^[0-9]+$ ]] || (( REPLICAS < 1 || REPLICAS > 50 ))
                                │
                                ▼
                   [ Multi-Tier Branch Logic ]
   ┌────────────────────────────┼────────────────────────────┐
   ▼                            ▼                            ▼
[ production ]               [ canary ]               [ staging / dev ]
├── critical:                ├── replicas <= 5:       └── AUTO_APPROVED (exit 0)
│   ├── replicas >= 3            AUTO_APPROVED
│   ├── branch: main|release/*  └── replicas > 5:
│   └── MANUAL_APPROVAL          REJECTED (exit 2)
└── standard:
    ├── branch: main|release/*|hotfix/*
    └── AUTO_APPROVED
```

---

## 5. Self-Assessment Checklist
Before you begin modifying `validator.sh`:

1. **Why does `[ -z $EMPTY_VAR ]` succeed, but `[ $EMPTY_VAR = "foo" ]` crash?**
   * *Answer*: In `[ $EMPTY_VAR = "foo" ]`, the unquoted variable vanishes, leaving `= "foo"`, which violates operator syntax. In `[ -z $EMPTY_VAR ]`, the argument list becomes `[ -z ]`, which POSIX defines as testing if the single argument `-z` is non-empty.
2. **Why is `[ expr1 -a expr2 ]` deprecated in the POSIX standard?**
   * *Answer*: POSIX marked `-a` and `-o` obsolescent because argument parsing becomes ambiguous when expressions contain values like `(`, `!`, or `-f`.
3. **How does `[[` prevent word splitting on unquoted variables?**
   * *Answer*: `[[` is parsed directly by the shell compiler as a special compound command, temporarily suppressing the word-splitting evaluation step.
4. **What is the difference between `[[ $V == *.log ]]` and `[[ $V == "*.log" ]]`?**
   * *Answer*: In `[[ $V == *.log ]]`, `*` is an active glob pattern. In `[[ $V == "*.log" ]]`, quotes make `*.log` a literal string match.
5. **How can you combine multiple conditions with grouping in `[[ ]]`?**
   * *Answer*: Using parentheses without backslash escaping: `[[ (cond1 || cond2) && cond3 ]]`.

---

## 6. Mission Objectives
Implement `validator.sh` as a production pre-flight deployment validator:
1. Accept 4 positional parameters: `<target_env>`, `<deploy_tier>`, `<replicas>`, `<branch>`.
2. Strictly use `[[ ]]` for all conditional tests (no single `[` brackets, no `-a` or `-o`).
3. Rejection rules (must print verdict and exit with code 2):
   - Missing/empty `TARGET_ENV`: `DEPLOY_VERDICT: REJECTED: MISSING_TARGET_ENV`.
   - Invalid replica count (not an integer, or not between 1 and 50): `DEPLOY_VERDICT: REJECTED: INVALID_REPLICA_COUNT`.
   - Unknown environment (not in `production`, `canary`, `staging`, `dev`): `DEPLOY_VERDICT: REJECTED: UNKNOWN_ENVIRONMENT`.
   - Production critical with < 3 replicas: `DEPLOY_VERDICT: REJECTED: INSUFFICIENT_CRITICAL_REPLICAS`.
   - Production with unapproved branch: `DEPLOY_VERDICT: REJECTED: UNAPPROVED_BRANCH_FOR_PROD`.
   - Canary with > 5 replicas: `DEPLOY_VERDICT: REJECTED: CANARY_REPLICA_EXCEEDED`.
4. Approval rules (must print verdict and exit with code 0):
   - Production critical passing all checks: `DEPLOY_VERDICT: MANUAL_APPROVAL_REQUIRED`.
   - Production standard passing all checks: `DEPLOY_VERDICT: AUTO_APPROVED`.
   - Canary with <= 5 replicas: `DEPLOY_VERDICT: AUTO_APPROVED`.
   - Staging or dev: `DEPLOY_VERDICT: AUTO_APPROVED`.
