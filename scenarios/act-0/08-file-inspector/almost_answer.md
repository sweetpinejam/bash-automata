# Code Blueprint & Almost-Answer: The File Inspector

If you need structural syntax guidance for `preflight.sh`:

### 1. Inode File Tests
```bash
# Check 1: Config file
if [[ -f "config/app.conf" && -s "config/app.conf" && -r "config/app.conf" ]]; then
    run_check "config_integrity" 1 "config/app.conf is valid and readable"
else
    run_check "config_integrity" 0 "config/app.conf missing, empty, or unreadable"
fi

# Check 2: Releases directory
if [[ -d "releases" && -w "releases" ]]; then
    run_check "release_dir_writable" 1 "releases/ is a writable directory"
else
    run_check "release_dir_writable" 0 "releases/ missing or not writable"
fi

# Check 3: Executable binary
if [[ -f "bin/app" && -x "bin/app" ]]; then
    run_check "binary_executable" 1 "bin/app is an executable regular binary"
else
    run_check "binary_executable" 0 "bin/app missing or not executable"
fi

# Check 4: Symlink integrity (detecting dangling links)
if [[ -L "current_release" && -e "current_release" ]]; then
    run_check "symlink_integrity" 1 "current_release points to a valid release target"
else
    run_check "symlink_integrity" 0 "current_release is missing, not a symlink, or dangling"
fi

# Check 5: Logs directory
if [[ -d "logs" && -w "logs" ]]; then
    run_check "logs_dir_writable" 1 "logs/ is a writable log directory"
else
    run_check "logs_dir_writable" 0 "logs/ missing or not writable"
fi
```
