#! /usr/bin/env bash
# Recreate the YubiKey's FIDO2 SSH key handle file on a new machine.
#
# The handle file (~/.ssh/id_ed25519_sk) is not a private key; it points at
# the credential stored on the YubiKey (wiki/ssh/minting-yubikey-ssh-keys.md).
# `ssh-keygen -K` downloads EVERY resident credential from EVERY connected
# FIDO2 authenticator, so this script runs it in a temp dir and installs only
# the credential whose public key matches the YubiKey line in ssh.nix.
#
#   init-ssh-handle.sh                           # the sk key in ssh.nix
#   init-ssh-handle.sh --fingerprint SHA256:...  # a specific key instead
#   init-ssh-handle.sh --force                   # overwrite an existing handle
#
# Writes ~/.ssh/id_ed25519_sk (mode 600) and ~/.ssh/id_ed25519_sk.pub.
# Refuses to overwrite either without --force. Needs the YubiKey plugged in;
# asks for its FIDO2 PIN and a touch.
set -euo pipefail

self=init-ssh-handle.sh
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ssh_nix="$repo/flake/modules/general-config/system/ssh/ssh.nix"
dest="$HOME/.ssh/id_ed25519_sk"
want=""
force=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fingerprint) want=${2:?--fingerprint needs a SHA256:... value}; shift 2 ;;
        --force) force=true; shift ;;
        -h|--help)
            sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "$self: unknown arg '$1'" >&2; exit 2 ;;
    esac
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# fingerprint_of <pubkey file> -> "SHA256:..."
fingerprint_of() { ssh-keygen -lf "$1" | awk '{print $2}'; }

if [[ -z $want ]]; then
    [[ -r $ssh_nix ]] || { echo "$self: can't read $ssh_nix; pass --fingerprint" >&2; exit 1; }
    mapfile -t lines < <(grep -o 'sk-ssh-ed25519@openssh.com [A-Za-z0-9+/=]*' "$ssh_nix")
    if [[ ${#lines[@]} -ne 1 ]]; then
        echo "$self: ${#lines[@]} sk keys in ssh.nix, expected 1; pass --fingerprint" >&2
        exit 1
    fi
    printf '%s\n' "${lines[0]}" > "$work/expected.pub"
    want=$(fingerprint_of "$work/expected.pub")
fi

if [[ $force != true ]]; then
    for f in "$dest" "$dest.pub"; do
        if [[ -e $f ]]; then
            echo "$self: $f already exists -- pass --force to overwrite" >&2
            exit 1
        fi
    done
fi

echo "looking for $want on the connected authenticator(s)" >&2
mkdir "$work/dl"
(cd "$work/dl" && ssh-keygen -K)

match=""
for pub in "$work"/dl/*.pub; do
    [[ -e $pub ]] || continue
    if [[ $(fingerprint_of "$pub") == "$want" ]]; then
        match=${pub%.pub}
        break
    fi
done

if [[ -z $match ]]; then
    echo "$self: no downloaded credential has fingerprint $want" >&2
    echo "$self: is the right YubiKey plugged in?" >&2
    exit 1
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
install -m 600 "$match" "$dest"
install -m 644 "$match.pub" "$dest.pub"

echo "wrote $dest (mode 600) and $dest.pub" >&2
echo "fingerprint: $(fingerprint_of "$dest.pub")" >&2
