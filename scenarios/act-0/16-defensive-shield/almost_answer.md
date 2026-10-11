# Code Blueprint: The Defensive Shell Shield (`set -euo pipefail`)

Activate strict error checking at the top of your scripts:

```bash
# Blueprint Pattern:
set -euo pipefail
```

> **Breakdown**:
> - `-e` (`errexit`): Exit immediately if a pipeline, list, or compound command exits with a non-zero status.
> - `-u` (`nounset`): Treat unset variables and parameters as an error when performing parameter expansion.
> - `-o pipefail`: Return the exit status of the last command in the pipe that failed (non-zero), rather than the status of the final command.
