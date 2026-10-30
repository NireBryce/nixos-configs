#!/usr/bin/env bash
# Runs factcheck's own fixture tests, from the flake input's source tree.
# Where the source is depends on the session, same ladder as
# flake/scripts/factcheck.sh:
#   1. $FACTCHECK_SRC -- exported by the dev shell
#   2. beside the factcheck binary on PATH (the package copies tests)
#   3. `nix develop` re-entry on a nix machine
set -eu

if [ -n "${FACTCHECK_SRC:-}" ] && [ -d "$FACTCHECK_SRC/tests" ]; then
    src=$FACTCHECK_SRC
elif command -v factcheck >/dev/null 2>&1; then
    src=$(cd "$(dirname "$(readlink -f "$(command -v factcheck)")")/../share/factcheck" && pwd)
else
    repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
    exec nix develop "$repo/flake" -c "$0" "$@"
fi

exec python3 -m unittest discover -s "$src/tests" -t "$src" "$@"
