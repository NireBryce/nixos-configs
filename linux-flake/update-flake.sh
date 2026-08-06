#! /usr/bin/env bash
set -euo pipefail

# Update all flake inputs, then confirm every host still evaluates.
#
# This previously ended mid-line on `./scripts/flake-file/flake-file-`, so the
# second half never ran. flake-file is not part of the normal loop: flake.nix
# is hand-maintained and the flake-file inputs are commented out, so the
# scripts under scripts/flake-file/ stay as one-off bootstrap helpers.

cd "$(dirname "$0")"

nix flake update
nix flake check
