---
name: low-side-secrets
description: How to add and maintain a sops file keyed to a personal SSH key instead of host keys, for secrets that don't need NixOS activation-time decryption.
---

# A sops file keyed to a user, not a host

## Applies to

Adding a new `<name>/secrets.yaml` under
`flake/modules/config-system/system/secrets/` whose recipient is a
personal SSH key (converted with `ssh-to-age`) rather than any host's SSH
host key — the pattern this repo calls "low-side": a secret whose real
access boundary is already enforced somewhere else (network ACLs, an
already-scoped API token) rather than by sops itself, so it's decrypted ad
hoc by whatever's running as that user instead of going through
`sops.secrets.*`/NixOS activation. `secrets/low-side/secrets.yaml` is the
worked example. Not for the main `secrets.yaml` — that stays host-key-only,
on purpose (see `secrets/sops.nix`'s own comment).

## Why this exists

Built 2026-09-17 for a Forgejo API token an agent session needed to fetch
without a human typing it in each time — access already fully bounded by
the tailnet, so the token itself is a convenience credential, not the real
gate. Two real bugs surfaced building the very first one; both are
mechanical traps that will silently recur, not one-off mistakes.

## Steps

1. **Enroll the pubkey.** `just age-key --pubkey-file ~/.ssh/id_ed25519.pub`
   converts it and prints the enrollment steps. Give it its own `&<name>`
   anchor under `.sops.yaml`'s `keys:` — reusing a host's anchor name
   collides; this isn't a host key, say so in a comment the way
   `.sops.yaml`'s existing `&elly` entry does.
2. **Add the `creation_rules` entry BEFORE the general `./secrets.yaml$`
   one, not after.** Neither `path` here is `^`-anchored — it's a Go
   regexp, so `.` matches any character and `./secrets.yaml$` also matches
   the last character of any path ending in `/secrets.yaml`, including a
   nested `low-side/secrets.yaml`. sops takes the *first* matching rule:
   list the general rule first and a new nested file silently gets
   encrypted for every host key instead of the one recipient you meant.
   Confirmed the hard way building the first one — `sops --encrypt`
   produced a file readable by all four hosts, not just the enrolled user.
   Verify after writing: `grep 'recipient:' <the new file>` should show
   exactly the key(s) you intended, nothing else.
3. **Materialize your own decrypt identity**: `just sops-user-identity`
   (wraps `flake/scripts/sops-user-identity.sh`) converts your SSH
   *private* key to a native age identity at
   `~/.config/sops/age/keys.txt`. Don't rely on
   `SOPS_AGE_SSH_PRIVATE_KEY_FILE` or sops's built-in SSH auto-detection —
   its conversion disagrees with `ssh-to-age` for the same key (upstream
   bug, Mic92/sops-nix#824, open, no fix expected) and decrypt fails
   against a provably-correct recipient with "identity did not match".
   Same root cause as `secrets/sops-interactive-key.nix`'s fix for root;
   this is the user-key version of it. One-time per host you need ad hoc
   decrypt access on — it's per-`$HOME`, not something that travels with
   the repo or the git branch.
4. **Create the file itself with a placeholder, never a real value typed
   through an agent session** — `sops --encrypt --in-place <file>` on a
   plaintext placeholder, then edit the real value in yourself with
   `sops <file>`. Skill `secrets-hygiene` covers why a value should never
   pass through a transcript.
5. **Verify decrypt works, narrowly**: `sops -d <file> >/dev/null 2>&1; echo $?`
   — exit 0, no plaintext printed. Confirms the recipient enrollment and
   the local identity file actually agree before calling it done.

## See also

- `secrets/sops.nix`'s history note — why the main `secrets.yaml` never
  gains a user-keyed recipient, kept separate on purpose.
- `secrets/sops-interactive-key.nix` — the root/host-key version of the
  ssh-to-age-vs-SOPS_AGE_SSH_PRIVATE_KEY_FILE mismatch this skill's step 3
  works around for a user key instead.
- Skill `secrets-hygiene` — never decrypt wider than the one value you
  need, and never let a secret value land in a conversation transcript.
- `wiki/impermanence-and-secrets.md`'s Secrets section — the human-facing
  overview this pattern is filed under.
