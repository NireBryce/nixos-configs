---
name: low-side-secrets
description: Adds and maintains a sops file keyed to a personal SSH key, for secrets that don't need activation-time decryption.
when_to_use: Adding a secrets file for an ad hoc secret whose recipient is a personal SSH key (via ssh-to-age). Not the main secrets.yaml.
---

# A sops file keyed to a user, not a host

**Needs:** bash-guards

## Applies to

Use when adding a `<name>/secrets.yaml` under `flake/modules/general-config/system/secrets/` whose recipient is a personal SSH key (via `ssh-to-age`) rather than a host SSH key. "Low-side" means the secret's real access boundary is enforced elsewhere (network ACLs, an already-scoped API token). Whatever runs as that user decrypts it ad hoc; it does not go through `sops.secrets.*` or NixOS activation. Worked example: `secrets/low-side/secrets.yaml`.

Do not use it for the main `secrets.yaml`, which stays host-key-only (see the comment on `&elly` in `.sops.yaml`).

## Why this exists

Built 2026-09-17 for a Forgejo API token that an agent session fetches without a human typing it. The tailnet already bounds access, so the token is a convenience credential. Steps 2 and 3 are the two mechanical traps found while building it; both recur silently.

## Steps

1. **Enroll the pubkey.** `just age-key --pubkey-file ~/.ssh/id_ed25519.pub` converts it and prints enrollment steps. Give it its own `&<name>` anchor under `keys:` in `.sops.yaml`; a host's anchor name collides. Comment that it is not a host key, as the existing `&elly` entry does.
2. **Add the `creation_rules` entry BEFORE the general `./secrets.yaml$` one.** Neither `path` is `^`-anchored. They are Go regexps, and `.` matches any character, so `./secrets.yaml$` also matches the tail of any `/secrets.yaml` path, including the nested `low-side/secrets.yaml`. sops takes the first match, so with the general rule first the nested file is encrypted for every host key without any error (this happened: `sops --encrypt` produced a file readable by every host). Verify with `grep 'recipient:' <new file>`; it must show exactly the intended key(s).
3. **Materialize your decrypt identity** with `just sops-user-identity` (wraps `flake/scripts/sops-user-identity.sh`). It converts your SSH *private* key to a native age identity at `~/.config/sops/age/keys.txt`. Do not use `SOPS_AGE_SSH_PRIVATE_KEY_FILE` or sops's SSH auto-detection: its conversion disagrees with `ssh-to-age` (upstream Mic92/sops-nix#824, open, no fix expected), so decrypt fails with "identity did not match" against a correct recipient. `secrets/sops-interactive-key.nix` (root version) has the same cause. Run it once per host and per `$HOME`; the identity does not travel with the repo.
4. **Create the file with a placeholder.** Never type a real value through an agent session. Run `sops --encrypt --in-place <file>` on a plaintext placeholder, then the user edits the real value with `sops <file>` (`secrets-hygiene`).
5. **Verify decrypt without printing.** Run `sops -d <file> >/dev/null 2>&1; echo $?`. Exit 0 with nothing printed confirms the recipient and your local identity agree.

## See also

- `.sops.yaml`'s comment on the `&elly` anchor: why the main `secrets.yaml` never gains a user-keyed recipient.
- `secrets/sops-interactive-key.nix`: root/host-key version of step 3's mismatch.
- Skill `secrets-hygiene`.
- `wiki/config-structure/impermanence-and-secrets.md` Secrets section: human overview.
