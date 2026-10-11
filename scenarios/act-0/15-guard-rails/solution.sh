#!/usr/bin/env bash
# ==============================================================================
# REFERENCE SOLUTION: DRILL 0.15 (Short-Circuit Guard Rails)
# ==============================================================================
set -euo pipefail

VERSION="1.0.0"

if [[ "${1:-}" == "--version" ]]; then
    VERSION="${2:-1.0.0}"
    shift 2
fi

validate_env() {
    [[ "$VERSION" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version format '$VERSION'" >&2; return 1; }
    mkdir -p dist
}

compile_manifest() {
    cat <<EOF > "dist/manifest.json"
{
  "version": "$VERSION",
  "status": "RELEASE_STAGED",
  "timestamp": 1700000000
}
EOF
}

generate_checksum() {
    sha256sum "dist/manifest.json" > "dist/manifest.sha256"
}

package_archive() {
    tar -czf "dist/release.tar.gz" -C dist manifest.json manifest.sha256
}

verify_bundle() {
    tar -tzf "dist/release.tar.gz" >/dev/null
}

# Execute linear short-circuit guard rails
validate_env      || { echo "FATAL: validate_env failed" >&2; exit 1; }
compile_manifest  || { echo "FATAL: compile_manifest failed" >&2; exit 1; }
generate_checksum || { echo "FATAL: generate_checksum failed" >&2; exit 1; }
package_archive   || { echo "FATAL: package_archive failed" >&2; exit 1; }
verify_bundle     || { echo "FATAL: verify_bundle failed" >&2; exit 1; }

SHA=$(cut -d' ' -f1 < "dist/manifest.sha256")
echo "PUBLISH_COMPLETE: version=$VERSION, archive=dist/release.tar.gz, checksum=$SHA"
