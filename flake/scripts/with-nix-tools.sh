#!/usr/bin/env bash
# Run a command with statix/deadnix on PATH: directly when they already are,
# otherwise inside this flake's dev shell (flake/modules/dev-shell.nix).
#
# They used to be on every host via packages-config/nix-utils/; since #486
# they live only in the dev shell, so `just lint` and .githooks/pre-commit
# would otherwise fail (or silently skip) outside `nix develop`. Re-entering
# the shell costs one devShell evaluation, and only when the tools are
# missing.
#
#   with-nix-tools.sh <flake-dir> <cmd> [args...]
set -euo pipefail

flake=${1:?usage: with-nix-tools.sh <flake-dir> <cmd> [args...]}
shift

if command -v statix >/dev/null && command -v deadnix >/dev/null; then
    exec "$@"
fi
exec nix develop "$flake" --command "$@"
