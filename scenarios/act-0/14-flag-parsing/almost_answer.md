# Code Blueprint & Almost-Answer: Flag & Argument Parsing

If you need structural parsing templates for `migrator.sh`:

### 1. The Canonical `while-case-shift` Loop
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        --env=*)
            ENV="${1#*=}"
            shift
            ;;
        -e|--env)
            [[ $# -ge 2 ]] || exit 1
            ENV="$2"
            shift 2
            ;;
        --timeout=*)
            TIMEOUT="${1#*=}"
            shift
            ;;
        -t|--timeout)
            [[ $# -ge 2 ]] || exit 1
            TIMEOUT="$2"
            shift 2
            ;;
        --)
            shift
            [[ $# -gt 0 ]] && { TARGET="$1"; shift $#; }
            break
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2
            exit 1
            ;;
        *)
            TARGET="$1"
            shift
            ;;
    esac
done
```

### 2. Parameter Validation
```bash
case "$ENV" in
    development|staging|production) ;;
    *) echo "Error: Invalid env" >&2; exit 1 ;;
esac

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || (( TIMEOUT < 5 || TIMEOUT > 3600 )); then
    exit 1
fi
```
