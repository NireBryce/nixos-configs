---
name: secrets-hygiene
description: How to avoid printing sops-managed secret values into the conversation in this repo, and what to do when one leaks anyway.
when_to_use: Any sops command, reading /run/secrets, "which secrets exist", env/printenv or journalctl near a unit that takes a secret, a secret value leaking into output.
---

# Handling sops secrets without leaking them

## Applies to

Any command touching `flake/modules/general-config/system/secrets/secrets.yaml`
or a decrypted secret on a live host (`/run/secrets/...`): checking decrypt
access, reading a value, adding/rotating one, verifying `sops updatekeys`
picked up a host. Also anything else that can carry a cleartext credential:
`env`/`printenv`, `journalctl` or `ps aux` near a unit that takes a secret
on its command line, an `EnvironmentFile`.

**Not** a concern for the *encrypted* `secrets.yaml`: `ENC[AES256_GCM,data:...]`
blocks are ciphertext, safe to `cat`, `git show`, `git diff`, and
deliberately committed (`CLAUDE.md` Safety). Danger is only in what has been
through `sops -d`, or a live `/run/secrets/` path.

## Why this exists

- **2026-08-26, `nire-tenacity`**: "can this session decrypt `secrets.yaml`?"
  answered with bare `sops -d secrets.yaml`, printing the whole file;
  `tailscale_key` and `atuin_key` landed in the transcript. Fix: rotate the
  Tailscale key — sent output can't be un-sent. `--extract`, or discarding
  stdout and reading `$?`, answers it with zero exposure.
- **2026-09-09, same host**, question "which secrets exist?":
  `sops -d … 2>/dev/null | grep -E "^[a-z_]+:"`. `2>/dev/null` satisfied the
  hook's `/dev/null` exemption while the decrypted file flowed through
  **stdout** into grep; `tailscale_key`, `tailscale_api_token`, `atuin_key`
  leaked (hyphenated names `ssh-*`, `restic-*`, `forgejo-admin-password`
  escaped only by regex luck). All rotated same-day. Result: the exemption
  needs an explicit **stdout** redirect and **no pipe** (hook fix), and
  "which keys exist" has a zero-decryption answer, `just read-sops-names`.

## Enforced mechanically, not just by memory

Hooks wired in `.agents/settings.json` (project-scoped, committed):

- **`.agents/hooks/secrets-guard-pretooluse.sh`** (`PreToolUse`, `Bash`):
  a `sops` decrypt (`-d`/`--decrypt`/`sops decrypt`) whose own pipeline
  stage has no `--extract` and doesn't send stdout to `/dev/null`;
  `sops exec-env`/`exec-file`; or anything touching `/run/secrets` /
  `/run/secrets.d` (or run with the cwd in there) other than a metadata
  command — `ls`, `stat`, `test`/`[`, `find` without an action →
  `permissionDecision: "deny"` naming the narrower alternative (was `ask`
  until 2026-09-29, a silent no-op under auto permission mode). Checks are
  per pipeline stage, so another command's `-d` (`cut -d=`, `grep -d`) on
  the same line doesn't count, and a text tool (`grep`, `rg`, `echo`, ...)
  merely naming sops passes. No task needs a deployed secret's contents,
  only that it exists with the right owner and mode. Retry with the named
  form; a genuine whole-file need is the user's to run by hand.
  **Prose trips it too**: a commit message or PR body that names the
  secrets path inline in the command is denied. Write the text to a file
  and pass it (`git commit -F <file>`, `gh pr create --body-file <file>`).
- **`permissions.deny`**: `Read(//run/secrets/**)` and
  `Read(//run/secrets.d/**)` — the Read tool (and, best-effort, Grep/Glob)
  never passes through a Bash hook, and some secrets are owned by the login
  user rather than root.
- **`.agents/hooks/secrets-guard-posttooluse.sh`** (`PostToolUse`, `Bash`):
  scans command output for a Tailscale auth key (`tskey-...`), age secret key
  (`AGE-SECRET-KEY-...`), private key block (`-----BEGIN ... PRIVATE KEY-----`),
  or a bare (non-`ENC[...]`) `tailscale_key`/`atuin_key` value → `decision:
  "block"`. It also fires on prose that merely quotes a marker (e.g. reading
  this file, 2026-09-29) — a false positive; check no real value
  printed.

Limits: the hooks see only `Bash` (the Read tool is covered by the deny
rules above, nothing else is); they match text, so they are guard rails,
not a boundary. Found 2026-09-09 with a fake `tskey-…` probe: **the ZCode harness
didn't fire these hooks at all**, so there the prose below is the ONLY
enforcement. Never assume a guard caught something; check output yourself.

## Preventing it

0. **"Which secrets exist?" never needs decryption:** `just read-sops-names`
   reads the committed ciphertext (key names are plaintext beside `ENC[...]`
   values); it cannot print a value. `sops -d` + grep caused both leaks.
1. **Before running a command against a secrets file, ask whether its default
   output includes plaintext you don't need.** Decrypt access needs only an
   exit code; one value needs only that key:
   ```sh
   sops -d secrets.yaml >/dev/null 2>&1; echo $?
   sops -d --extract '["tailscale_key"]' secrets.yaml
   ```
   Never bare `sops -d secrets.yaml` (or `cat` a `/run/secrets/...` path)
   when a narrower form answers the question.
2. **Value genuinely needed** (for `sops set`, a comparison): still extract
   just that key, not the whole file.
3. **Unpredictable output size/content**: redirect to a file, inspect
   narrowly (`grep`, `wc -l`).
4. **Same rule for non-obvious carriers** — `env`, `journalctl -u <unit with
   a secret in argv/EnvironmentFile>`, `ps aux` near one: is there a
   narrower way to get the answer?

## Catching it when something slips through anyway

0. **Check `.agents/known-dead-secrets.md` before treating a hit as fresh**
   — skill `triage-flagged-secrets` has the procedure. Hooks can re-flag a
   secret already confirmed dead in old git history; matching first avoids a
   rotation-panic over something inert.
1. Before quoting/summarizing output from any command above, scan for
   secret-shaped content: Tailscale auth key (`tskey-...`), age key (`age1...`
   as a *secret*, or `AGE-SECRET-KEY-...`), SSH private key block, recovery
   phrase (plain words next to a key name like `atuin_key`), or any
   `secrets.yaml` key name (`tailscale_key`, `atuin_key`, `syncthing-*`,
   `ssh-*`) beside a value rather than `ENC[...]`.
2. Don't requote a leaked value; refer to it by name ("the `tailscale_key`
   value"). Repeating it only adds copies.
3. If a secret leaked, say so immediately, same turn, naming exactly which
   and recommending rotation (new Tailscale key, regenerated recovery
   phrase, changed password). Don't offer to "remove it from the transcript"
   — impossible; implying otherwise understates it.
4. Judge honestly: public SSH keys and syncthing device IDs aren't secrets
   in plaintext — no rotation claim for those; don't skip auth keys,
   passwords, recovery phrases, private keys.

## See also

- `triage-flagged-secrets` skill and `.agents/known-dead-secrets.md` —
  registry of confirmed-dead secrets.
- The two hook scripts above (wired in `.agents/settings.json`
  `hooks.PreToolUse`/`hooks.PostToolUse`): read before assuming a new
  risky-command shape is covered; if not, extend the pattern match, not just
  this prose.
- `CLAUDE.md` Safety — why `secrets.yaml` is encrypted-but-committed, which
  hosts are enrolled.
- `flake/modules/general-config/system/secrets/sops.nix` — how secrets are
  declared and wired to services.
