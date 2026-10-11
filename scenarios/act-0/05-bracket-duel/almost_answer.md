# Code Blueprint: Modern Compound Test Conditions (`[[ ... ]]`)

Modern Bash provides `[[ ... ]]` with built-in logical operators (`&&`, `||`) which does not perform word-splitting on empty or spaced variables:

```bash
# Blueprint Pattern:
# Logical AND:
if [[ "$TARGET_ENV" == "production" && "$DEPLOY_TIER" == "critical" ]]; then
  echo "DEPLOY_VERDICT: MANUAL_APPROVAL_REQUIRED"

# Logical OR:
elif [[ "$TARGET_ENV" == "staging" || "$TARGET_ENV" == "dev" ]]; then
  echo "DEPLOY_VERDICT: AUTO_APPROVED"

# Empty string check (-z):
elif [[ -z "$TARGET_ENV" ]]; then
  echo "DEPLOY_VERDICT: TARGET_ENV_MISSING"
```

> **Key Rule**: Avoid legacy `[` with `-a` or `-o` flags. Inside `[[ ]]`, use `&&` and `||`.
