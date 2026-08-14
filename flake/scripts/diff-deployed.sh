#! /usr/bin/env bash
# Package-level diff between what this machine is running and what it would
# install.
#
#   diff-deployed.sh [host]
#
# Answers the question a drvPath cannot: which packages actually move. A nixpkgs
# bump shows up here as a list of version changes rather than as one different
# hash, which is most of what you want to know before switching across a release.
#
# Needs the new toplevel to exist, so run it AFTER `just build` and before
# `just boot`. Linux only, and only meaningful on the host itself -- it compares
# against /run/current-system.
set -euo pipefail

host=${1:-nire-durandal}

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
flake_dir=$(dirname -- "$script_dir")

top=$(cd "$flake_dir" && nix eval --raw \
    ".#nixosConfigurations.${host}.config.system.build.toplevel")

# Guarded rather than left to nix. Unbuilt, `nix store diff-closures` fails with
# "there is no substituter that can build it", which is true and unhelpful --
# the actual problem is that a step was skipped.
if [[ ! -e $top ]]; then
    echo "diff-deployed: ${host} is not built yet -- run \`just build\` first." >&2
    echo "  wanted: $top" >&2
    exit 1
fi

exec nix store diff-closures /run/current-system "$top"
