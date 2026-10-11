# Code Blueprint: Constant $O(1)$ Memory Ingestion Streaming

Never slurp unbounded log streams into shell arrays (`declare -a records`). Read and write one record at a time to stay under tight cgroup memory limits (e.g. 64MB):

```bash
# Blueprint Pattern:
# Constant-memory stream processing:
while IFS= read -r line; do
  echo "PROCESSED: $line"
done < feed.raw > "$output_file"
```

> **Key Rule**: Redirecting the output directly from the `while` loop (`done < input > output`) avoids allocating megabytes of shell memory and avoids append-mode (`>>`) disk seek thrashing.
