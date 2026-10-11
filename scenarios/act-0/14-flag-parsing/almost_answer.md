# Code Blueprint: CLI Flag Parsing with `shift` and `case`

Robust CLI flag parsing does not rely on hardcoded `$1` or `$2`. Use a loop that consumes arguments with `shift`:

```bash
# Blueprint Pattern:
while (( $# > 0 )); do
  case "$1" in
    -e|--env)
      env="$2"
      shift 2
      ;;
    -d|--dry-run)
      dry_run="true"
      shift
      ;;
    -v|--verbose)
      verbose="true"
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      shift
      ;;
  esac
done
```

> **Key Rule**: Use `shift 2` when an option consumes an accompanying value argument (`$2`), and `shift 1` for standalone boolean flags.
