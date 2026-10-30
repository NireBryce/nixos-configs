#!/usr/bin/env bash
# Runs factcheck, from wherever this environment can get it.
#
# The tool is the factcheck flake input, not a checkout copy, so where it
# is depends on the session:
#
#   1. on PATH            -- inside the dev shell (flake/modules/dev-shell.nix
#                            puts the input's package there); instant.
#   2. $FACTCHECK_SRC     -- the dev shell also exports the input's source
#                            tree, for anything that needs its tests.
#   3. `nix develop`      -- a bare shell on a nix machine re-enters the
#                            dev shell; costs a moment of eval.
#   4. otherwise          -- exit 75: no way to fetch the input here (the
#                            offline-hooks case). Callers decide; the edit
#                            hook treats it as silence, CI runs the check.
set -u

if command -v factcheck >/dev/null 2>&1; then
    exec factcheck "$@"
fi

if [ -n "${FACTCHECK_SRC:-}" ] && [ -x "$FACTCHECK_SRC/bin/factcheck" ]; then
    exec python3 "$FACTCHECK_SRC/bin/factcheck" "$@"
fi

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
if command -v nix >/dev/null 2>&1; then
    exec nix develop "$repo/flake" -c factcheck "$@"
fi

echo "factcheck: not on PATH and nix cannot fetch the flake input here -- " \
     "left to CI" >&2
exit 75
