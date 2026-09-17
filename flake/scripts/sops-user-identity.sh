#! /usr/bin/env bash
# Materialize a LOCAL sops decrypt identity from your own SSH key -- the
# private-key half of enrolling a user (not host) key as a sops recipient,
# e.g. for a low-side/secrets.yaml-style file (skill `low-side-secrets`).
#
# host-age-key.sh only ever reads a public key and prints; it deliberately
# never touches private key material. This is the other half: converts
# YOUR ssh private key to a native age identity and writes it to the
# standard sops lookup path, ~/.config/sops/age/keys.txt (Linux, and
# darwin too -- sops-darwin.nix already points SOPS_AGE_KEY_FILE at this
# same Linux-XDG path there, so this script never needs to branch on
# platform).
#
#   sops-user-identity.sh                     # ~/.ssh/id_ed25519
#   sops-user-identity.sh -i ~/.ssh/other_key  # a different key
#   sops-user-identity.sh --force              # overwrite an existing keys.txt
#
# Refuses to overwrite an existing keys.txt without --force -- something
# else may already rely on whatever's there.
#
# WHY THIS EXISTS: sops's own built-in SSH-key-to-age conversion
# (SOPS_AGE_SSH_PRIVATE_KEY_FILE) produces a DIFFERENT age identity than
# ssh-to-age for the same key (upstream bug, Mic92/sops-nix#824, open) --
# and only checks ~/.ssh/id_rsa by default. Since .sops.yaml enrolls every
# key in this repo via ssh-to-age, decrypting has to go through the same
# conversion or it fails against every recipient with "identity did not
# match" despite the key being correct. Hit chasing this exact failure
# 2026-08-29 for root (secrets/sops-interactive-key.nix) and again
# 2026-09-17 for a user key (skill `low-side-secrets`).
set -euo pipefail

key_file="$HOME/.ssh/id_ed25519"
force=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i) key_file=${2:?-i needs a path}; shift 2 ;;
        --force) force=true; shift ;;
        -h|--help)
            sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "sops-user-identity.sh: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

[[ -r $key_file ]] || { echo "sops-user-identity.sh: can't read $key_file" >&2; exit 1; }

out_dir="$HOME/.config/sops/age"
out_file="$out_dir/keys.txt"

if [[ -e $out_file && $force != true ]]; then
    echo "sops-user-identity.sh: $out_file already exists -- pass --force to overwrite" >&2
    exit 1
fi

run_ssh_to_age() {
    if command -v ssh-to-age >/dev/null 2>&1; then
        ssh-to-age "$@"
    else
        nix --extra-experimental-features 'nix-command flakes' \
            run nixpkgs#ssh-to-age -- "$@"
    fi
}

mkdir -p "$out_dir"
run_ssh_to_age -private-key -i "$key_file" -o "$out_file"
chmod 600 "$out_file"

echo "wrote $out_file (mode 600)" >&2
echo "" >&2
echo "public half, to enroll in .sops.yaml (host-age-key.sh's steps apply" >&2
echo "the same way, just with a name like &elly instead of a hostname):" >&2
run_ssh_to_age -i "${key_file}.pub"
