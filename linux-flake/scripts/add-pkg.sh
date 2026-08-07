#! /usr/bin/env bash
# Create a package module, correctly wrapped and opted into its group.
#
#   add-pkg.sh <cli|gui|linux-utils> <name> [subdir]
#   add-pkg.sh cli ripgrep
#   add-pkg.sh gui inkscape image-editors
#
# There are 100+ of these and they are pure boilerplate. The part worth
# automating is the opt-in line: forget it and the module is still valid, still
# evaluates, and simply never installs anything.
set -euo pipefail

group=${1:-}
name=${2:-}
subdir=${3:-}

case ${group} in
    cli|gui|linux-utils) ;;
    *)
        echo "usage: add-pkg.sh <cli|gui|linux-utils> <name> [subdir]" >&2
        exit 2
        ;;
esac
if [[ -z ${name} ]]; then
    echo "usage: add-pkg.sh <cli|gui|linux-utils> <name> [subdir]" >&2
    exit 2
fi
if [[ ! ${name} =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "add-pkg.sh: '${name}' is not a usable nix attribute name" >&2
    exit 2
fi

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
flake_dir=$(dirname -- "${script_dir}")
aggregate="pkgs-${group}"
dir=${flake_dir}/modules/pkgs/${group}${subdir:+/${subdir}}
file=${dir}/${name}.nix

if [[ -e ${file} ]]; then
    echo "add-pkg.sh: ${file#"${flake_dir}"/} already exists" >&2
    exit 1
fi

# Module names share one namespace per class, so a duplicate would silently
# merge into the existing module rather than create a new one.
if existing=$(grep -rl "flake\.modules\.homeManager\.${name}\b *=" "${flake_dir}/modules" 2>/dev/null); then
    echo "add-pkg.sh: homeManager module '${name}' is already declared in:" >&2
    printf '  %s\n' "${existing[@]#"${flake_dir}"/}" >&2
    exit 1
fi

mkdir -p "${dir}"
cat >"${file}" <<EOF
# desc = "";
{ config, ... }:
{
    flake.modules.homeManager.${aggregate}.imports = [ config.flake.modules.homeManager.${name} ];

    flake.modules.homeManager.${name} =
{ pkgs, ... }:
{
    home.packages = with pkgs; [
        ${name}
    ];
}
;}
EOF

echo "created ${file#"${flake_dir}"/}"
echo
echo "next:"
echo "  git add ${file#"${flake_dir}"/}      # nix cannot see untracked files"
echo "  just check                           # or nix eval a host toplevel"
