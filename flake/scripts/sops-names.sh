#! /usr/bin/env bash
# List the KEY NAMES defined in the sops-encrypted secrets.yaml -- without
# decrypting anything.
#
#   sops-names.sh [file]        (default: the repo's secrets.yaml)
#
# sops encrypts VALUES only: in the committed file every sensitive name
# sits next to an `ENC[AES256_GCM,...]` blob, so parsing the ciphertext can
# never print a value, by construction -- there is no decryption step to
# mis-redirect. This exists because "which secrets does this repo have?"
# has been answered by piping `sops -d` through grep twice now (2026-08-26
# and 2026-09-09), landing plaintext values in the session transcript both
# times; the second time through a `2>/dev/null` that only looked like a
# stdout redirect. Names printed here are safe; the same question must
# never be answered by decrypting.
#
# The names of `ssh-*`/`syncthing-*` entries appear too. Their VALUES are
# public-key material (not secrets), but names alone are printed for
# everything regardless -- a name says nothing a directory listing doesn't.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "$0")/../.." && pwd)
file="${1:-$repo_root/flake/modules/nire/system/secrets/secrets.yaml}"

if [ ! -f "$file" ]; then
    echo "no secrets file at $file" >&2
    exit 2
fi

# Key names with their indentation, in file order; stop at sops's own
# trailing metadata block (`sops:` and everything under it is bookkeeping,
# not a secret name).
awk '/^sops:/{exit} {print}' "$file" \
    | sed -nE 's/^([[:space:]]*[A-Za-z0-9_-]+):.*/\1/p'
