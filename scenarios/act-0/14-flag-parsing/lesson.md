# Tactical Field Manual: Flag & Argument Parsing (The Canonical `while-case-shift` Loop)

## 1. Systems Mental Model: The Anatomy of CLI Arguments
Every command executed on Linux receives its argument list via the kernel's `execve(2)` system call as an array of strings: `argv[0], argv[1], ... argv[N]`.
In Bash:
* `$0`: The name or path of the script itself.
* `$1`, `$2`, `$3`: Positional arguments 1, 2, 3.
* `$#`: The count of positional arguments currently remaining.
* `$@`: An array of all positional arguments, preserving quoting when expanded as `"$@"`.
* `shift [n]`: Drops the first `n` arguments, sliding `$2` into `$1`, `$3` into `$2`, and decrementing `$#` by `n`.

### Why `getopts` is Often Inadequate
The shell built-in `getopts` is a legacy POSIX utility:
* ❌ It does **not** support GNU-style long options (e.g. `--dry-run`, `--env=prod`).
* ❌ It cannot handle attached `=` syntax without clumsy manual workarounds.
Because modern DevOps and cloud tooling mandates long options (`--verbose`, `--timeout=30`), the modern industry gold standard is the **manual `while-case-shift` loop**.

---

## 2. Syntax Anatomy: The Canonical `while-case-shift` Pattern

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        # 1. Boolean flags (no arguments):
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;

        # 2. Options taking arguments:
        # Handling attached syntax: --env=production
        --env=*)
            ENV="${1#*=}"
            shift
            ;;
        # Handling space-separated syntax: -e production or --env production
        -e|--env)
            ENV="${2:-}"
            [[ -n "$ENV" ]] || { echo "Error: Missing argument for $1" >&2; exit 1; }
            shift 2
            ;;

        # 3. End-of-options delimiter (--):
        --)
            shift
            # All remaining arguments are positional!
            POSITIONAL+=("$@")
            break
            ;;

        # 4. Unknown options:
        -*)
            echo "Error: Unknown option '$1'" >&2
            exit 1
            ;;

        # 5. Non-option positional arguments:
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done
```

---

## 3. Parsing Attached (`--flag=val`) vs Space-Separated (`--flag val`)

A robust CLI parser must accept both standard conventions:
```bash
# Style A: Attached with equals sign
./migrator.sh --timeout=60

# Style B: Separate with space
./migrator.sh --timeout 60
```

Using Bash parameter expansion `${1#*=}`:
* `${1#*=}` strips everything up to the first `=` sign.
* If `$1` is `--timeout=60`, `${1#*=}` evaluates to `60` in memory!
* Then shift **1**.
* If `$1` is `--timeout` and `$2` is `60`, read `$2` and shift **2**.

---

## 4. Architectural Diagram: CLI Parser State Machine

```
[ CLI: ./migrator.sh -d --env=prod --timeout 30 20261011_add_users ]
                             │
                             ▼
                 [ while [[ $# -gt 0 ]] ]
                             │
     ┌───────────────────────┼───────────────────────┐
     ▼                       ▼                       ▼
[ -d|--dry-run ]        [ --env=* ]             [ --timeout ]
- DRY_RUN=true          - ENV="${1#*=}"         - TIMEOUT="$2"
- shift 1               - shift 1               - shift 2
                             │
                             ▼
                 [ Remaining: $# == 1 ]
                             │
                             ▼
                     [ Positional (*) ]
             TARGET="$1" -> "20261011_add_users"
             shift 1
                             │
                             ▼
                 [ Loop Terminates: $# == 0 ]
                 [ Validate Parameters ]
                 [ Emit migration_plan.json ]
```

---

## 5. Self-Assessment Checklist
Before you begin modifying `migrator.sh`:

1. **What does the `shift` built-in do to the argument stack?**
   * *Answer*: It discards `$1`, shifts all subsequent arguments down by one (`$2` becomes `$1`, `$3` becomes `$2`), and decrements `$#` by 1.
2. **Why does an option with a required argument need `shift 2` when space-separated?**
   * *Answer*: Because the option flag occupies `$1` and the argument value occupies `$2`. Both must be consumed before parsing the next token.
3. **How does `${1#*=}` extract the value from `--env=staging`?**
   * *Answer*: It strips the shortest prefix matching `*=` from `$1`, leaving only `"staging"`.
4. **What is the standard convention for the `--` delimiter?**
   * *Answer*: It signals the end of options; all subsequent arguments are treated strictly as positional operands, even if they begin with a hyphen.
5. **How should an unknown option (starting with `-`) be handled?**
   * *Answer*: It should be matched by `-*)`, print an informative error message to `stderr`, and exit with code 1.

---

## 6. Mission Objectives
Implement `migrator.sh` as an enterprise CLI parser and normalizer:
1. Support short and long options in arbitrary order:
   - `-e <env>` / `--env=<env>` / `--env <env>`: environment (`development`, `staging`, `production`; default: `development`).
   - `-d` / `--dry-run`: boolean flag (default: `false`).
   - `-v` / `--verbose`: boolean flag (default: `false`).
   - `-t <sec>` / `--timeout=<sec>` / `--timeout <sec>`: integer timeout between 5 and 3600 (default: 30).
   - `--batch-size=<N>` / `--batch-size <N>`: integer batch size between 1 and 10000 (default: 100).
   - `--force`: boolean flag (default: `false`).
   - `--`: end-of-options marker.
2. Positional target argument:
   - First non-option positional parameter is `<target>` (default: `"all"`).
3. Validate:
   - `env` must be in `development`, `staging`, `production`.
   - `timeout` and `batch_size` must be integers within valid bounds.
   - Any unknown flag matching `-*` must print error to `stderr` and exit 1.
4. Output valid `migration_plan.json` containing the normalized configuration.
5. Output summary: `MIGRATOR_READY: env=<E>, dry_run=<D>, timeout=<T>, batch=<B>, target=<M>`.
