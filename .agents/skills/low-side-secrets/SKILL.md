---
name: low-side-secrets
description: How to add and maintain a sops file keyed to a personal SSH key instead of host keys, for secrets that don't need NixOS activation-time decryption.
---

# A sops file keyed to a user, not a host

## Applies to

Adding a new `<name>/secrets.yaml` under
`flake/modules/general-config/system/secrets/` whose recipient is a personal
SSH key (via `ssh-to-age`), not a host SSH key — "low-side": the secret's
real access boundary is enforced elsewhere (network ACLs, an already-scoped
API token), so it's decrypted ad hoc by whatever runs as that user, not via
`sops.secrets.*`/NixOS activation. Worked example:
`secrets/low-side/secrets.yaml`. Not for the main `secrets.yaml` — stays
host-key-only on purpose (`secrets/sops.nix` comment).

## Why this exists

Built 2026-09-17 for a Forgejo API token an agent session fetches without a
human typing it (access already bounded by the tailnet; the token is a
convenience credential). Two mechanical traps surfaced (steps 2 and 3); both
silently recur.

## Steps

1. **Enroll the pubkey.** `just age-key --pubkey-file ~/.ssh/id_ed25519.pub`
   converts it and prints enrollment steps. Give it its own `&<name>` anchor
   under `.sops.yaml`'s `keys:` (a host's anchor name collides); comment that
   it isn't a host key, as the existing `&elly` entry does.
2. **Add the `creation_rules` entry BEFORE the general `./secrets.yaml$`
   one.** Neither `path` is `^`-anchored — Go regexp, `.` matches any char,
   so `./secrets.yaml$` also matches the tail of any `/secrets.yaml` path,
   including nested `low-side/secrets.yaml`. sops takes the *first* match:
   general rule first → the nested file is silently encrypted for every host
   key (happened: `sops --encrypt` produced a file readable by all four
   hosts). Verify: `grep 'recipient:' <new file>` shows exactly the intended
   key(s).
3. **Materialize your decrypt identity**: `just sops-user-identity` (wraps
   `flake/scripts/sops-user-identity.sh`) converts your SSH *private* key to
   a native age identity at `~/.config/sops/age/keys.txt`. Don't use
   `SOPS_AGE_SSH_PRIVATE_KEY_FILE` or sops's SSH auto-detection: its
   conversion disagrees with `ssh-to-age` (upstream Mic92/sops-nix#824, open,
   no fix expected) and decrypt fails with "identity did not match" against
   a correct recipient. Same root cause as `secrets/sops-interactive-key.nix`
   (root version). One-time per host, per-`$HOME`; doesn't travel with the repo.
4. **Create the file with a placeholder, never a real value typed through an
   agent session**: `sops --encrypt --in-place <file>` on a plaintext
   placeholder, then the user edits the real value with `sops <file>`
   (`secrets-hygiene`).
5. **Verify decrypt narrowly**: `sops -d <file> >/dev/null 2>&1; echo $?` —
   exit 0, nothing printed; confirms recipient and local identity agree.

## See also

- `secrets/sops.nix` history note — why the main `secrets.yaml` never gains a
  user-keyed recipient.
- `secrets/sops-interactive-key.nix` — root/host-key version of step 3's mismatch.
- Skill `secrets-hygiene`.
- `wiki/impermanence-and-secrets.md` Secrets section — human overview.
