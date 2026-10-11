# Code Blueprint: Filesystem Inspection Operators

Use Bash test operators inside `[[ ... ]]` to verify filesystem prerequisites before proceeding:

```bash
# Blueprint Pattern:
# 1. Non-empty file check (-s: exists AND size > 0):
if [[ ! -s "$config_file" ]]; then
  echo "FAIL: config/app.conf missing or empty"
  exit 1
fi

# 2. Directory check (-d: exists AND is a directory):
if [[ ! -d "$release_dir" ]]; then
  echo "FAIL: releases directory missing"
  exit 1
fi

# 3. Executable check (-x: exists AND has execute permission):
if [[ ! -x "$app_bin" ]]; then
  echo "FAIL: bin/app not executable"
  exit 1
fi
```

> **Key Rule**: Test with negative logic `[[ ! -s ... ]]` to fail fast and guard downstream commands against broken dependencies.
