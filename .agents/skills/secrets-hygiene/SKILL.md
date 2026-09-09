---
name: secrets-hygiene
description: How to avoid printing sops-managed secret values into the conversation in this repo, hook-enforced where the pattern is checkable, and what to do when one leaks anyway.
---

# Handling sops secrets without leaking them

## Applies to

Any command that touches `flake/modules/nire/system/secrets/secrets.yaml`
or a decrypted secret on a live host (`/run/secrets/...`) — checking
whether decrypt access works, reading a value, adding or rotating one,
verifying `sops updatekeys` picked up a new host. Also applies more
broadly to anything else that can carry a credential in cleartext:
`env`/`printenv`, `journalctl` near a unit that takes a secret on its
command line, `ps aux` near one that does the same, an `EnvironmentFile`.

**Not** a concern for the *encrypted* form of `secrets.yaml` itself —
`ENC[AES256_GCM,data:...]` blocks are ciphertext, safe to `cat`, `git
show`, or `git diff`, and are deliberately committed per `CLAUDE.md`'s
Safety section. The danger is exclusively in anything that has already
been through `sops -d`, or a live `/run/secrets/` path, or otherwise
decrypted.

## Why this exists

2026-08-26, on `nire-tenacity`: "can this session even decrypt
`secrets.yaml`?" was answered with a bare `sops -d secrets.yaml`, which
prints the entire file — `tailscale_key` and `atuin_key` landed in the
transcript. The fix was rotating the Tailscale key; output already sent
can't be un-sent. A targeted check (`--extract`, or discard stdout and read
`$?`) would have answered the same question with zero exposure.

It happened again 2026-09-09, same host, same question ("which secrets
exist?"), different hole: `sops -d … 2>/dev/null | grep -E "^[a-z_]+:"` —
the `2>/dev/null` satisfied this hook's `/dev/null` exemption while the
whole decrypted file flowed through **stdout** into grep, and three values
(`tailscale_key`, `tailscale_api_token`, `atuin_key`) landed in the
transcript. Only regex luck kept the hyphenated names (`ssh-*`,
`restic-*`, `forgejo-admin-password`) out — their values were one
character-class away from printing too. All three were rotated same-day.
Two lessons now baked in: the exemption requires an explicit **stdout**
redirect and **no pipe** (hook fix, same commit), and "which keys exist"
has a dedicated zero-decryption answer, `just read-sops-names`.

## Enforced mechanically, not just by memory

Two hooks in `.agents/settings.json` (project-scoped, committed) wire the
checkable parts:

- **`.agents/hooks/secrets-guard-pretooluse.sh`** (`PreToolUse`, `Bash`) —
  a bare `sops -d`/`--decrypt` with no `--extract` and no `>/dev/null`, or
  a `cat`/`bat`/`less`/`more`/`head`/`tail` on a `/run/secrets/` path,
  triggers `permissionDecision: "ask"` naming the narrower alternative.
- **`.agents/hooks/secrets-guard-posttooluse.sh`** (`PostToolUse`, `Bash`) —
  scans actual command output for a Tailscale auth key (`tskey-...`), an age
  secret key (`AGE-SECRET-KEY-...`), a private key block (`-----BEGIN ...
  PRIVATE KEY-----`), or a bare (non-`ENC[...]`)
  `tailscale_key`/`atuin_key` value; a hit returns `decision: "block"`.

Known limits: `Bash` tool only (a `Read` of a decrypted file is not
caught); patterns are specific shapes plus this repo's two sensitive key
names, so an unrecognized credential shape won't flag. And the big one,
found 2026-09-09 by probing with a fake `tskey-…` string: **the ZCode
harness did not fire these hooks at all** — the probe sailed through
unflagged — so under that harness the hooks are decoration and the
sections below are the ONLY enforcement. Never assume a guard caught
something; check the output yourself. The sections below are the judgment
the hooks can't cover.

## Preventing it

0. **"Which secrets exist?" never needs decryption:** `just read-sops-names`
   reads the committed ciphertext, where sops leaves key names as plaintext
   next to `ENC[...]` values — it cannot print a value by construction.
   Reaching for `sops -d` plus grep to answer it is how both leaks
   happened.
1. **Before running a command against a secrets file, ask: does its
   default output include plaintext I don't actually need?** Testing
   decrypt access needs only an exit code:
   ```sh
   sops -d secrets.yaml >/dev/null 2>&1; echo $?
   ```
   Reading one value needs only that key:
   ```sh
   sops -d --extract '["tailscale_key"]' secrets.yaml
   ```
   Never run a bare `sops -d secrets.yaml` (or `cat` a decrypted
   `/run/secrets/...` path) when a narrower form answers the actual
   question.
2. **When a value genuinely must be read** (to hand to `sops set`, to
   compare against something), still extract just that one key rather than
   the whole file — the other keys in `secrets.yaml` aren't relevant to the
   task and don't need to be in the transcript to accomplish it.
3. **When a command's output size or content isn't predictable up front**,
   redirect it to a file first and inspect that narrowly (`grep`, `wc -l`)
   rather than letting the raw output land directly in a reply.
4. **This applies to the same class of command even when secrets aren't
   the obvious subject** — `env`, `journalctl -u <unit that takes a
   secret as an argv or EnvironmentFile>`, `ps aux` near such a unit. The
   test is the same: does this command's default output plausibly include
   something that isn't meant to be read back, and is there a narrower way
   to get the answer.

## Catching it when something slips through anyway

1. Before quoting or summarizing a tool result that came from any command
   in the categories above, scan it for secret-shaped content: a Tailscale
   auth key (`tskey-...`), an age key (`age1...` as a *secret*, or
   `AGE-SECRET-KEY-...`), an SSH private key block
   (`-----BEGIN OPENSSH PRIVATE KEY-----`), a recovery phrase (a run of
   plain words next to a key name like `atuin_key`), or any
   `secrets.yaml` key name (`tailscale_key`, `atuin_key`, `syncthing-*`,
   `ssh-*`) sitting next to a value rather than `ENC[...]`.
2. If a tool result already contains one of these, don't requote it in
   your own reply — refer to it by name only ("the `tailscale_key`
   value"). The moment it appeared in any tool output it's already
   exposed; repeating it in prose adds nothing but more copies.
3. If a secret did leak, say so immediately, in the same turn, rather than
   continuing whatever task was in progress as if nothing happened. Name
   exactly which secret(s) leaked and recommend rotation — a new
   Tailscale key, a regenerated recovery phrase, a changed password.
   Don't offer to "remove it from the transcript" — that isn't something
   available, and implying otherwise understates what actually happened.
4. Judge sensitivity honestly rather than flagging everything: public SSH
   keys and syncthing device IDs aren't secrets even in plaintext — don't
   claim a rotation is needed for those, but don't skip flagging the ones
   that are (auth keys, passwords, recovery phrases, private keys).

## See also

- `.agents/hooks/secrets-guard-pretooluse.sh` and
  `.agents/hooks/secrets-guard-posttooluse.sh` — the actual enforcement,
  wired in `.agents/settings.json`'s `hooks.PreToolUse`/`hooks.PostToolUse`.
  Read these before assuming a new risky-command shape is covered; if it
  isn't, extend the pattern match rather than only adding prose here.
- `CLAUDE.md`'s Safety section — why `secrets.yaml` is encrypted-but-committed
  on purpose, and which hosts are enrolled.
- `flake/modules/nire/system/secrets/sops.nix` — how secrets are declared
  and wired to services in this repo.
