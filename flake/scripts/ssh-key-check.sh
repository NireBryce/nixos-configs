#! /usr/bin/env bash
# Fail the build when the invoking user's ~/.ssh holds unencrypted private
# keys.
#
#   ssh-key-check.sh [ssh-dir]          # default: ~/.ssh
#
# Wired into rebuild.sh ahead of any nix work, so every `just build`,
# `switch` and `boot` runs it; `just ssh-key-check` runs it standalone.
#
# HOW THE CHECK WORKS -- read before touching, this is the delicate part.
#
# Each candidate file gets exactly one command:
#
#     ssh-keygen -y -P '' -f <file> >/dev/null 2>&1
#
# `-y` derives the public half from the private key; `-P ''` supplies an
# empty passphrase. On an unencrypted key the derivation succeeds (exit 0).
# On an encrypted one it fails: the OpenSSH format stores a matching
# check-int pair inside the encrypted section, so an empty passphrase
# decrypts the section to garbage and ssh-keygen bails before producing
# anything. BOTH streams are discarded unconditionally: on success
# ssh-keygen would print the public half -- public, but not this script's
# business -- and on failure it prints a generic error. This script emits
# only file paths and verdicts, so no key material, public or private, is
# ever printed, written, or sent anywhere, and the check is read-only
# against the key files: nothing is decrypted to disk, nothing is modified.
#
# A file that fails the derivation is not automatically "encrypted": it may
# not be a private key at all. Those are identified with `ssh-keygen -lf`,
# which fingerprints the embedded public half without decrypting anything,
# and skipped rather than judged.
#
# SUPPRESSING: an unencrypted key can be deliberate -- an agent key whose
# scope is bounded by authorizedKeys options, a key pending deletion. Name
# it, per run, in SSH_KEYS_ALLOW_UNENCRYPTED (comma-separated basenames, no
# spaces); suppressed files still produce a one-line notice, so suppression
# is visible rather than silent, and nothing persists it:
#
#     SSH_KEYS_ALLOW_UNENCRYPTED=id_ed25519-agent just build
#
# OUT OF SCOPE: key file permissions (a 0600 check is a different gate) and
# keys outside ~/.ssh (nothing else in this fleet keeps private keys).
set -euo pipefail

dir=${1:-"$HOME/.ssh"}

# No ~/.ssh, nothing to say.
[ -d "$dir" ] && [ -r "$dir" ] || exit 0

allow=${SSH_KEYS_ALLOW_UNENCRYPTED:-}
allowed() {
    [ -n "$allow" ] || return 1
    printf '%s\n' "$allow" | tr ',' '\n' | grep -qxF -- "$(basename -- "$1")"
}

offending=()
suppressed=()
for key in "$dir"/id_*; do
    [ -e "$key" ] || continue                        # unmatched glob
    case $key in *.pub|*.pub.*) continue ;; esac     # public halves
    # Not a private key at all: not this check's business (its derivation
    # would fail for a reason that has nothing to do with encryption).
    ssh-keygen -lf "$key" >/dev/null 2>&1 || continue
    if ssh-keygen -y -P '' -f "$key" >/dev/null 2>&1; then
        if allowed "$key"; then
            suppressed+=("$(basename -- "$key")")
        else
            offending+=("$key")
        fi
    fi
done

if [ "${#offending[@]}" -gt 0 ]; then
    echo "ssh-key-check: UNENCRYPTED SSH PRIVATE KEYS in $dir:" >&2
    printf '  %s\n' "${offending[@]}" >&2
    echo "Encrypt one in place -- same key, so every host keeps accepting it:" >&2
    echo "  ssh-keygen -p -a 100 -f <path>    # store the passphrase first" >&2
    echo "Delete it if it is dead. For a deliberately unencrypted key (e.g. an" >&2
    echo "agent key scoped by authorizedKeys options), suppress this run only:" >&2
    echo "  SSH_KEYS_ALLOW_UNENCRYPTED=<basename>[,<basename>...] $(basename -- "$0")" >&2
    exit 1
fi

if [ "${#suppressed[@]}" -gt 0 ]; then
    echo "ssh-key-check: unencrypted keys allowed this run:${suppressed[@]/#/ }" >&2
fi
