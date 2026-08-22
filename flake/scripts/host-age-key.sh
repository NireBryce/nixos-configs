#! /usr/bin/env bash
# A host's sops recipient key, the way every host in this repo actually gets
# one: not a standalone `age-keygen` keypair (nothing here uses that), but the
# host's own ed25519 SSH host key, converted with ssh-to-age. That's what
# sops.age.sshKeyPaths (sops.nix) points at on the decrypting side, and what
# .sops.yaml's `keys:` list holds on the encrypting side -- see
# flake/modules/nire/system/secrets/.sops.yaml for durandal/lysithea/tenacity/
# cube's existing entries, and CLAUDE.md's Safety section for lego, which
# doesn't have one yet.
#
#   host-age-key.sh                        # this machine's own host key
#   host-age-key.sh <host>                  # a remote host, via ssh-keyscan
#   host-age-key.sh --pubkey-file <path>    # a pubkey you already have on disk
#   host-age-key.sh --updatekeys            # re-encrypt secrets.yaml for
#                                            # .sops.yaml's CURRENT keys list
#
# This script only ever reads a PUBLIC key and only ever prints. It does not
# edit .sops.yaml for you -- CLAUDE.md and the new-host-config skill are both
# explicit that enrollment happens "when that need actually arises, not
# preemptively", and a `keys:` entry plus which `creation_rules` group it
# belongs to is a judgement call this script has no way to make safely by
# text-munging YAML. Paste the printed line in by hand, then re-run this
# script with --updatekeys.
#
# THE REMOTE-HOST CASE IS UNAUTHENTICATED. `ssh-keyscan` fetches whatever key
# the host offers on port 22 without checking it against any known_hosts entry
# -- that is what makes it work without an interactive login, and also what
# makes it spoofable by anything positioned to MITM the connection. Fine for
# "the machine sitting next to me on the same LAN, being enrolled for the
# first time"; if that assumption doesn't hold, fetch the pubkey over a
# channel you already trust (console, an existing SSH known_hosts entry,
# `just baseline` output) and pass it with --pubkey-file instead.
#
# ssh-to-age is not part of environment.systemPackages anywhere in this repo
# (only `sops` is, see sops.nix) and is not assumed to be on PATH -- this
# falls back to `nix run` for it, same reasoning as rebuild.sh falling back
# rather than assuming `nh` is installed.
set -euo pipefail

pubkey_file=""
do_updatekeys=false
target=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pubkey-file) pubkey_file=${2:?--pubkey-file needs a path}; shift 2 ;;
        --updatekeys)  do_updatekeys=true; shift ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        -*) echo "host-age-key.sh: unknown flag '$1'" >&2; exit 2 ;;
        *) target=$1; shift ;;
    esac
done

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
flake_dir=$(dirname -- "$script_dir")
secrets_dir="$flake_dir/modules/nire/system/secrets"

run_ssh_to_age() {
    if command -v ssh-to-age >/dev/null 2>&1; then
        ssh-to-age
    else
        nix --extra-experimental-features 'nix-command flakes' \
            run nixpkgs#ssh-to-age -- "$@"
    fi
}

if $do_updatekeys; then
    if [[ -n $pubkey_file || -n $target ]]; then
        echo "host-age-key.sh: --updatekeys re-encrypts for .sops.yaml's" >&2
        echo "  current keys list; it doesn't take a host or pubkey-file." >&2
        exit 2
    fi
    echo "==> re-encrypting secrets.yaml for .sops.yaml's current keys" >&2
    ( cd "$secrets_dir" && sops updatekeys secrets.yaml )
    exit 0
fi

if [[ -n $pubkey_file ]]; then
    [[ -r $pubkey_file ]] || { echo "host-age-key.sh: can't read $pubkey_file" >&2; exit 1; }
    pubkey=$(cat "$pubkey_file")
    source_desc="$pubkey_file"
elif [[ -n $target ]]; then
    echo "==> ssh-keyscan against $target (unauthenticated -- see this" \
         "script's header)" >&2
    scanned=$(ssh-keyscan -t ed25519 -T 5 "$target" 2>/dev/null | grep -v '^#' || true)
    [[ -n $scanned ]] || {
        echo "host-age-key.sh: no ed25519 host key answered from $target" >&2
        echo "  (unreachable, no sshd, or it only offers rsa/ecdsa)" >&2
        exit 1
    }
    # ssh-keyscan prefixes each line with the hostname/IP queried with; strip
    # that back off so what's left is a bare "ssh-ed25519 AAAA... " pubkey,
    # the same shape ssh-to-age expects whether it came from keyscan or a
    # local .pub file.
    pubkey=$(awk '{ $1=""; print }' <<<"$scanned" | sed 's/^ //')
    source_desc="ssh-keyscan $target"
else
    local_key=/etc/ssh/ssh_host_ed25519_key.pub
    [[ -r $local_key ]] || {
        echo "host-age-key.sh: can't read $local_key on this machine." >&2
        echo "  Pass a host to scan remotely, or --pubkey-file <path>." >&2
        exit 1
    }
    pubkey=$(cat "$local_key")
    source_desc="$local_key (this machine)"
fi

age_pub=$(run_ssh_to_age <<<"$pubkey")

host_name=${target:-$(hostname)}
echo "source: $source_desc" >&2
echo "" >&2
echo "age public key:"
echo "  $age_pub"
echo "" >&2
echo "to enroll in $secrets_dir/.sops.yaml:" >&2
echo "  1. add under keys:" >&2
echo "       - &${host_name} ${age_pub}" >&2
echo "  2. add *${host_name} to the key_groups this host's secrets belong in" >&2
echo "  3. host-age-key.sh --updatekeys" >&2
