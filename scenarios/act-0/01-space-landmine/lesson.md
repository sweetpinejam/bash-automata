# Tactical Field Manual: The Space Landmine (Word Splitting)

## 1. The Mental Model (How Linux & Bash Handle Spaces)
In Python, strings are atomic data structures:
```python
path = "deploy artifacts"
os.mkdir(path)  # Creates ONE folder named "deploy artifacts"
```

In Bash, the shell uses whitespace (spaces, tabs, newlines) as the default delimiter (**Internal Field Separator / IFS**) between command arguments:
```bash
PATH_DIR="deploy artifacts"
mkdir $PATH_DIR  # BASH EXPANDS THIS AS: mkdir deploy artifacts (Creates TWO folders: "deploy" and "artifacts"!)
```

This shell behavior is called **Word Splitting**. It is the #1 cause of bugs in Linux shell scripts and automated deployment pipelines.

## 2. Syntax Cheatsheet: Quoting Rules
```bash
# ❌ VULNERABLE: Word-splitting splits path into multiple arguments
mkdir -p $DEST_DIR
mv $SRC_DIR/* $DEST_DIR/

# ✅ BULLETPROOF: Double quotes protect spaces from word-splitting
mkdir -p "$DEST_DIR"
mv "$SRC_DIR"/* "$DEST_DIR"/

# ⚠️ NOTE ON WILDCARDS (*):
# Keep wildcards outside quotes so the shell can expand them:
# "$SRC_DIR"/*   <- Expands correctly to all files inside "$SRC_DIR"
# "$SRC_DIR/*"   <- WRONG: Looks for a literal file named '*'
```

## 3. Deadly Pitfall in CI/CD Automation
Imagine an automated sweep:
```bash
TARGET_DIR="old logs/*"
rm -rf $TARGET_DIR   # Expands to: rm -rf old logs/* -> Attempts to delete "old" and "logs/*"!
```
If `TARGET_DIR` expands unexpectedly, unquoted variables can delete or corrupt entirely unintended directories on your host.

## 4. Recommended Reading List
Before executing this drill, review:
* `man 1 bash` (Search for: `Word Splitting`)
* Greg's Bash Wiki: [Quotes](https://mywiki.wooledge.org/Quotes) & [WordSplitting](https://mywiki.wooledge.org/WordSplitting)
* ShellCheck Wiki: Rule `SC2086` (Double quote to prevent globbing and word splitting)

## 5. Mission Objective
Edit `cleaner.sh` in your sandbox. Protect all variable expansions with double quotes so the automated archival sweep moves all files into `"archived runs"` cleanly with exit code 0.
