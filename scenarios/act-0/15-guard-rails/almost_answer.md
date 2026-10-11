# Code Blueprint: Short-Circuit Pipeline Guard Rails

Flatten deeply nested `if [ $? -eq 0 ]` blocks using POSIX short-circuit `||` error handling:

```bash
# Blueprint Pattern:
run_tests || { echo "ERROR: Tests failed" >&2; exit 1; }
build_bundle || { echo "ERROR: Build failed" >&2; exit 1; }
sign_bundle || { echo "ERROR: Signing failed" >&2; exit 1; }

echo "PUBLISH_SUCCESS"
```

> **Key Rule**: When grouping commands inside `{ ...; }`, the closing curly brace MUST be preceded by a semicolon or a newline, with spaces surrounding the braces.
