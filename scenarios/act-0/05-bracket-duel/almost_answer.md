# Code Blueprint & Almost-Answer: The Bracket Duel

If you need architectural guidance to structure the policy checks in `validator.sh`:

### 1. Empty & Numeric Guards with `[[ ]]`
```bash
if [[ -z "${TARGET_ENV// /}" ]]; then
    echo "DEPLOY_VERDICT: REJECTED: MISSING_TARGET_ENV"
    exit 2
fi

if [[ ! "$REPLICAS" =~ ^[0-9]+$ ]] || (( REPLICAS < 1 || REPLICAS > 50 )); then
    echo "DEPLOY_VERDICT: REJECTED: INVALID_REPLICA_COUNT"
    exit 2
fi
```

### 2. Production Branch Matching & Policy Cascading
```bash
if [[ "$TARGET_ENV" == "production" ]]; then
    if [[ "$DEPLOY_TIER" == "critical" ]]; then
        if (( REPLICAS < 3 )); then
            echo "DEPLOY_VERDICT: REJECTED: INSUFFICIENT_CRITICAL_REPLICAS"
            exit 2
        fi
        if [[ "$BRANCH" != "main" && "$BRANCH" != release/* ]]; then
            echo "DEPLOY_VERDICT: REJECTED: UNAPPROVED_BRANCH_FOR_PROD"
            exit 2
        fi
        echo "DEPLOY_VERDICT: MANUAL_APPROVAL_REQUIRED"
        exit 0
    elif [[ "$DEPLOY_TIER" == "standard" ]]; then
        if [[ "$BRANCH" != "main" && "$BRANCH" != release/* && "$BRANCH" != hotfix/* ]]; then
            echo "DEPLOY_VERDICT: REJECTED: UNAPPROVED_BRANCH_FOR_PROD"
            exit 2
        fi
        echo "DEPLOY_VERDICT: AUTO_APPROVED"
        exit 0
    fi
```

### 3. Canary & Non-Prod Environments
```bash
elif [[ "$TARGET_ENV" == "canary" ]]; then
    if (( REPLICAS > 5 )); then
        echo "DEPLOY_VERDICT: REJECTED: CANARY_REPLICA_EXCEEDED"
        exit 2
    fi
    echo "DEPLOY_VERDICT: AUTO_APPROVED"
    exit 0
elif [[ "$TARGET_ENV" == "staging" || "$TARGET_ENV" == "dev" ]]; then
    echo "DEPLOY_VERDICT: AUTO_APPROVED"
    exit 0
else
    echo "DEPLOY_VERDICT: REJECTED: UNKNOWN_ENVIRONMENT"
    exit 2
fi
```
