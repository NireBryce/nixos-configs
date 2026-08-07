#! /usr/bin/env bash
# Print a dotfile as home-manager will actually generate it.
#
#   dotfile.sh .zshrc [host]
#   dotfile.sh .blerc nire-tenacity
#
# Most shell bugs in this repo are invisible in the .nix source and obvious in
# the generated file -- duplicated blocks, ordering, a later definition winning.
# Piping to `grep -n` is usually the point.
#
# Exists mainly because the home.file attribute name is inconsistent: entries
# have shown up as ".zshrc", "./.zshrc" and "/home/elly/.zsh/plugins/...", so
# guessing it wastes a round trip. This resolves it by suffix match.
set -euo pipefail

name=${1:-}
host=${2:-nire-durandal}
if [[ -z ${name} ]]; then
    echo "usage: dotfile.sh <name> [host]     e.g. dotfile.sh .zshrc" >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
flake_dir=$(dirname -- "${script_dir}")
# Addressed by absolute path, not `.#`: just runs recipes from the justfile
# directory, which is the repo root and has no flake.nix.
base="${flake_dir}#nixosConfigurations.${host}.config"

user=$(nix eval --raw "${base}.nire.primaryUser" 2>/dev/null) || {
    echo "dotfile.sh: cannot evaluate ${host}" >&2; exit 1; }
files=${base}.home-manager.users.${user}.home.file

mapfile -t attrs < <(
    nix eval --json --apply 'builtins.attrNames' "${files}" 2>/dev/null \
        | python3 -c 'import json,sys; [print(a) for a in json.load(sys.stdin)]'
)

matches=()
for a in "${attrs[@]}"; do
    [[ ${a} == "${name}" || ${a} == */"${name}" || ${a##*/} == "${name}" ]] && matches+=("${a}")
done

if [[ ${#matches[@]} -eq 0 ]]; then
    echo "dotfile.sh: no home.file entry matching '${name}' for ${user}@${host}." >&2
    echo "available:" >&2
    printf '  %s\n' "${attrs[@]}" >&2
    exit 1
fi
if [[ ${#matches[@]} -gt 1 ]]; then
    echo "dotfile.sh: '${name}' is ambiguous:" >&2
    printf '  %s\n' "${matches[@]}" >&2
    exit 1
fi

attr=${matches[0]}
text=$(nix eval --raw "${files}.\"${attr}\".text" 2>/dev/null || true)

if [[ -n ${text} ]]; then
    printf '%s\n' "${text}"
    exit 0
fi

# Some entries carry no .text and are built from a derivation instead.
source_path=$(nix eval --raw "${files}.\"${attr}\".source" 2>/dev/null || true)
if [[ -z ${source_path} ]]; then
    echo "dotfile.sh: '${attr}' has neither .text nor .source" >&2
    exit 1
fi
if [[ -r ${source_path} ]]; then
    cat -- "${source_path}"
else
    echo "dotfile.sh: '${attr}' is built from a derivation, not inline text:" >&2
    echo "  ${source_path}" >&2
    echo "That is an x86_64-linux path, so it cannot be read from darwin." >&2
    echo "Run this on the host, or inspect the source module directly." >&2
    exit 1
fi
