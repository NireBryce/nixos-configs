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
#
# Exits 75 (EX_TEMPFAIL) when the tools are not on PATH and nix cannot
# provide them -- no nix, or the dev shell will not evaluate (the flake
# inputs cannot be fetched, as in a sandbox with no route to GitHub). That
# is "could not run the check", which a caller must be able to tell from the
# command itself failing: .githooks/pre-commit degrades to the checks that
# need no nix on 75 and fails on anything else. The probe is a
# `nix develop ... --command true`; when it succeeds the real run below
# reuses the evaluation, and when it fails it fails in under a second.
set -euo pipefail

flake=${1:?usage: with-nix-tools.sh <flake-dir> <cmd> [args...]}
shift

if command -v statix >/dev/null && command -v deadnix >/dev/null; then
    exec "$@"
fi
if ! command -v nix >/dev/null; then
    echo "with-nix-tools: statix/deadnix not on PATH and no nix to provide them" >&2
    exit 75
fi
if ! nix develop "$flake" --command true >/dev/null 2>&1; then
    echo "with-nix-tools: nix cannot enter the dev shell here (inputs unfetchable?)" >&2
    exit 75
fi
exec nix develop "$flake" --command "$@"
