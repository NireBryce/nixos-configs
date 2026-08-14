#! /usr/bin/env bash
# What Home Manager generates, as it will actually land on disk.
#
#   dotfiles.sh <host> <user>           # list every managed file's attribute name
#   dotfiles.sh <host> <user> ./.zshrc  # print one file's generated content
#
# Reading the .nix source is full of false negatives; reading the output is not.
# Most shell bugs here are invisible in the module and obvious in the file.
#
# Two traps, both of which have cost time:
#
#   The attribute name is inconsistent. ".zshrc", "./.zshrc" and full
#   /home/elly/... paths all occur in the same config, and a wrong name returns
#   EMPTY rather than erroring -- which reads exactly like a real negative.
#   That is why the list form exists: run it first, copy the name from it.
#
#   Some entries have no .text at all and are built from .source; .bashrc is
#   one. For those, read the owning option instead -- programs.bash.initExtra --
#   because this will print nothing and look like the file is empty.
#
# Evaluation only, so it works from darwin.
set -euo pipefail

host=${1:-nire-durandal}
user=${2:-elly}
name=${3:-}

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
flake_dir=$(dirname -- "$script_dir")
cd "$flake_dir"

attr=".#nixosConfigurations.${host}.config.home-manager.users.${user}.home.file"

if [[ -z $name ]]; then
    nix eval --json "$attr" --apply builtins.attrNames \
        | tr ',' '\n' | tr -d '[]"'
    exit 0
fi

out=$(nix eval --raw "${attr}.\"${name}\".text" 2>/dev/null) || {
    echo "dotfiles.sh: no .text for '${name}'." >&2
    echo "  Check the name against \`just dotfiles\`, and note that entries" >&2
    echo "  built from .source have no .text -- read the owning option instead." >&2
    exit 1
}
printf '%s' "$out"
