# Tactical Field Manual: Flag & Argument Parsing (`shift` & `$#`)

## 1. The Mental Model (How Shell Scripts Process CLI Arguments)
When a script is called with arguments (`./script -v --env prod file.txt`):
* **`$#`**: The total count of positional arguments passed.
* **`$1`, `$2`, `$3`...**: The individual arguments by index.
* **`$@`**: All positional arguments as a list of quoted strings `"$@"`.

In manual scripts, hardcoding `$1` and `$2` breaks as soon as a user passes options in a different order or includes optional flags (`-v`).

The standard Unix design pattern uses a **while loop with `shift`**:
```
                 ┌─────────────────────────────────────┐
  Arguments:     │  $1: --dry-run  │  $2: -e  │  $3: prod  │
                 └─────────────────────────────────────┘
                                  ▼
                            [ shift 1 ]
                                  ▼
                 ┌─────────────────────────────────────┐
  New $1, $2:    │  $1: -e         │  $2: prod             │
                 └─────────────────────────────────────┘
```

The command **`shift N`** shifts all positional arguments to the left by `N` positions:
`$1` is discarded, `$2` becomes the new `$1`, `$3` becomes the new `$2`, and `$#` is decremented by `N`.

---

## 2. Syntax Cheatsheet: The Standard CLI Parser Loop

```bash
env="development"
dry_run="false"
verbose="false"

while (( $# > 0 )); do
    case "$1" in
        -e|--env)
            env="${2:?Error: --env requires a value}"
            shift 2  # Consumes the flag AND its value
            ;;
        -d|--dry-run)
            dry_run="true"
            shift 1  # Consumes only the flag
            ;;
        -v|--verbose)
            verbose="true"
            shift 1
            ;;
        --)
            shift    # End of flags marker
            break
            ;;
        -*)
            echo "Error: Unknown flag '$1'" >&2
            exit 1
            ;;
        *)
            # Non-flag positional argument (e.g. filename)
            files+=("$1")
            shift 1
            ;;
    esac
done
```

---

## 3. Deadly Pitfall: Shifting Past Zero Arguments
If a flag requires an argument (`--env <val>`) but the user ran `./script --env` (forgetting the value), doing `shift 2` when `$# == 1` causes Bash to throw:
`shift: shift count must be <= $#`.
Always guard values using `${2:?Error message}` before shifting!

---

## 4. Recommended Reading List
* `man 1 bash` (Search for: `shift [n]`)
* Greg's Bash Wiki: [BashFAQ/035: How to handle command-line arguments](https://mywiki.wooledge.org/BashFAQ/035)
* Linux CLI Standards: POSIX Utility Syntax Guidelines

---

## 5. Mission Objective
Edit `migrator.sh` in your sandbox. Implement a `while (( $# > 0 ))` loop with `case` and `shift` so that `--env|-e`, `--dry-run|-d`, and `--verbose|-v` are parsed accurately in any order into `migration.cfg`.
