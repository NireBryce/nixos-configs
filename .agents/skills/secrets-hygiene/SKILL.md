---
name: secrets-hygiene
description: Keeps sops-managed secret values out of the conversation, and covers what to do when one leaks.
when_to_use: Running any sops command, reading /run/secrets, asking which secrets exist, running env, printenv or journalctl near a unit that takes a secret, or a secret value showing up in output.
---

# Handling sops secrets without leaking them

**Needs:** bash-guards

## Applies to

Any command touching `flake/modules/general-config/system/secrets/secrets.yaml`
or a decrypted secret on a live host (`/run/secrets/...`): checking decrypt
access, reading a value, adding or rotating one, verifying `sops updatekeys`
picked up a host. Also anything else that can carry a cleartext credential:
`env`/`printenv`, `journalctl` or `ps aux` near a unit that takes a secret on
its command line, an `EnvironmentFile`.

The encrypted `secrets.yaml` is safe: its `ENC[AES256_GCM,data:...]` blocks are
ciphertext, safe to `cat`, `git show` and `git diff`, and it is committed on
purpose (`CLAUDE.md` Safety). The danger is output that has been through
`sops -d`, or a live `/run/secrets/` path.

## Why this exists

- **2026-08-26, `nire-tenacity`**: the question "can this session decrypt
  `secrets.yaml`?" was answered with bare `sops -d secrets.yaml`, which printed
  the whole file. `tailscale_key` and `atuin_key` landed in the transcript. The
  Tailscale key was rotated, because sent output cannot be un-sent. `--extract`,
  or discarding stdout and reading `$?`, answers the question with no exposure.
- **2026-09-09, same host**, question "which secrets exist?": the command was
  `sops -d … 2>/dev/null | grep -E "^[a-z_]+:"`. `2>/dev/null` met the hook's
  `/dev/null` exemption while the decrypted file flowed through stdout into
  grep. `tailscale_key`, `tailscale_api_token` and `atuin_key` leaked; the
  hyphenated names (`ssh-*`, `restic-*`, `forgejo-admin-password`) escaped only
  because the regex did not match them. All were rotated the same day. The
  hook's exemption now requires an explicit stdout redirect and no pipe, and
  "which keys exist" has an answer that decrypts nothing: `just
  read-sops-names`.

## Enforced mechanically, not just by memory

Hooks wired in `.agents/settings.json` (project-scoped, committed):

- **`.agents/hooks/secrets-guard-pretooluse.sh`** (`PreToolUse`, `Bash`):
  returns `permissionDecision: "deny"`, naming the narrower alternative, for:
  - a `sops` decrypt (`-d`/`--decrypt`/`sops decrypt`) whose own pipeline stage
    has no `--extract` and does not send stdout to `/dev/null`;
  - `sops exec-env`/`exec-file`;
  - anything touching `/run/secrets` or `/run/secrets.d` (or run with the cwd
    in there) other than a metadata command: `ls`, `stat`, `test`/`[`, `find`
    without an action.

  The verdict was `ask` until 2026-09-29, which does nothing under auto
  permission mode. Checks run per pipeline stage, so another command's `-d`
  (`cut -d=`, `grep -d`) on the same line does not count, and a text tool
  (`grep`, `rg`, `echo`, ...) that only names sops passes. No task needs a
  deployed secret's contents, only that it exists with the right owner and
  mode. Retry with the named alternative; a whole-file need is for the user to
  run by hand.

  Prose trips it too: a commit message or PR body that names the secrets path
  inline in the command is denied. Write the text to a file and pass it (`git
  commit -F <file>`, `gh pr create --body-file <file>`).
- **`permissions.deny`**: `Read(//run/secrets/**)` and
  `Read(//run/secrets.d/**)`. The Read tool (and, best-effort, Grep/Glob) never
  passes through a Bash hook, and some secrets are owned by the login user
  rather than root.
- **`.agents/hooks/secrets-guard-posttooluse.sh`** (`PostToolUse`, `Bash`):
  returns `decision: "block"` when command output contains a Tailscale auth key
  (`tskey-...`), an age secret key (`AGE-SECRET-KEY-...`), a private key block
  (`-----BEGIN ... PRIVATE KEY-----`), or a bare (non-`ENC[...]`)
  `tailscale_key`/`atuin_key` value. It also fires on prose that quotes a
  marker (e.g. reading this file, 2026-09-29). That is a false positive; check
  that no real value printed.

Limits: the hooks see only `Bash` (the deny rules above cover the Read tool;
nothing else is covered), and they match text, so they are guard rails, not a
boundary. Check output yourself instead of assuming a guard caught something.

ZCode does not read `.agents/settings.json`. Its hooks come from
`.zcode/config.json` (`hooks.events`, run only with `hooks.enabled: true`),
which since 2026-10-04 mirrors the same hooks (generated from
`.agents/settings.json`; the `polymorph` flake check keeps the two in step).
Before that date ZCode ran none of them (fake `tskey-…` probe, 2026-09-09).
Live-checked 2026-10-04 on ZCode 3.14.3 (#448): the SessionStart context, the
git and secrets denies, the secrets output scan and the edit hooks all fire
(ZCode's `Edit` passes `file_path`). ZCode treats an `ask` as allow, so only a
deny is enforced there, and only `additionalContext` reaches its model. ZCode's
docs describe no equivalent of the `permissions.deny` Read rules.

## Preventing it

0. **Answering "which secrets exist?" never needs decryption.** `just
   read-sops-names` reads the committed ciphertext (key names are plaintext
   beside the `ENC[...]` values) and cannot print a value. `sops -d` plus grep
   caused both leaks.
1. **Before running a command against a secrets file, check whether its default
   output includes plaintext you do not need.** Decrypt access needs only an
   exit code; one value needs only that key:
   ```sh
   sops -d secrets.yaml >/dev/null 2>&1; echo $?
   sops -d --extract '["tailscale_key"]' secrets.yaml
   ```
   Never run bare `sops -d secrets.yaml` (or `cat` a `/run/secrets/...` path)
   when a narrower form answers the question.
2. **When you need a value** (for `sops set`, a comparison), extract just that
   key, not the whole file.
3. **When the output size or content is unpredictable**, redirect to a file and
   inspect it narrowly (`grep`, `wc -l`).
4. **Apply the same rule to other carriers**: `env`, `journalctl -u <unit with
   a secret in argv/EnvironmentFile>`, `ps aux` near one. Look for a narrower
   way to get the answer.

## Catching it when something slips through anyway

0. **Check `.agents/known-dead-secrets.md` before treating a hit as fresh.**
   Skill `triage-flagged-secrets` has the procedure. The hooks can re-flag a
   secret already confirmed dead in old git history, and matching first avoids
   an unneeded rotation.
1. **Before quoting or summarizing output from any command above, scan it for
   secret-shaped content**: a Tailscale auth key (`tskey-...`), an age key
   (`age1...` as a secret, or `AGE-SECRET-KEY-...`), an SSH private key block, a
   recovery phrase (plain words next to a key name like `atuin_key`), or any
   `secrets.yaml` key name (`tailscale_key`, `atuin_key`, `restic-*`, `ssh-*`)
   beside a value rather than `ENC[...]`.
2. **Do not requote a leaked value.** Refer to it by name ("the `tailscale_key`
   value"); repeating it adds copies.
3. **If a secret leaked, say so in the same turn**, naming exactly which one
   and recommending rotation (new Tailscale key, regenerated recovery phrase,
   changed password). Do not offer to remove it from the transcript; that is
   impossible.
4. **Judge what counts as a secret.** Public SSH keys and syncthing device IDs
   are not secrets in plaintext, so make no rotation claim for them. Always
   treat auth keys, passwords, recovery phrases and private keys as secrets.

## See also

- `triage-flagged-secrets` skill and `.agents/known-dead-secrets.md` — registry
  of confirmed-dead secrets.
- The two hook scripts above (wired in `.agents/settings.json`
  `hooks.PreToolUse`/`hooks.PostToolUse`): read them before assuming a new
  risky-command shape is covered; if it is not, extend the pattern match, not
  just this prose.
- `CLAUDE.md` Safety — why `secrets.yaml` is encrypted but committed;
  `.agents/rules/secrets.md` — which hosts are enrolled.
- `flake/modules/general-config/system/secrets/sops.nix` — how secrets are
  declared and wired to services.
