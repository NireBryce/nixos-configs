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

2026-08-26, on `nire-tenacity`: mid-way through wiring a new sops secret for
a Forgejo admin password, the question "can this session even decrypt
`secrets.yaml`?" got answered with a bare `sops -d secrets.yaml` — no
`--extract`, no output suppression. That prints the *entire* file. It
printed `tailscale_key` and `atuin_key` in plaintext into the transcript,
along with several lower-sensitivity SSH pubkeys and syncthing device IDs.
Elly caught it, not Claude, before the reply that would have quoted it — a
targeted check (`--extract`, or discarding stdout and reading `$?`) would
have answered the same question with zero exposure. The fix afterward was
"rotate the Tailscale key," not "redact the message" — output already sent
can't be un-sent.

## Enforced mechanically, not just by memory

Prose guidance is exactly what failed on 2026-08-26 — the discipline below
was already the obvious approach and got skipped anyway, under no real
pressure, because nothing forced it. So the two most mechanically-checkable
parts of this skill are wired as real hooks in `.claude/settings.json`
(project-scoped, committed, applies every session in this repo — not
something to re-derive from memory each time):

- **`.claude/hooks/secrets-guard-pretooluse.sh`** (`PreToolUse`, `Bash`
  matcher) — pattern-matches the command *before* it runs. A bare `sops
  -d`/`--decrypt` with no `--extract` and no `>/dev/null`, or a
  `cat`/`bat`/`less`/`more`/`head`/`tail` reading a path under
  `/run/secrets/`, triggers `permissionDecision: "ask"` with the narrower
  alternative in the reason text — this is the exact command shape that
  caused the leak.
- **`.claude/hooks/secrets-guard-posttooluse.sh`** (`PostToolUse`, `Bash`
  matcher) — scans the command's actual output *after* it runs, regardless
  of which command produced it, for a Tailscale auth key (`tskey-...`), an
  age secret key (`AGE-SECRET-KEY-...`), a private key block
  (`-----BEGIN ... PRIVATE KEY-----`), or a bare (non-`ENC[...]`)
  `tailscale_key`/`atuin_key` value. A hit returns `decision: "block"`,
  which feeds a warning back into context immediately — before there's a
  chance to quote the result in a reply.

Both were pipe-tested against synthetic hook input and proven to fire live
in-session (a sentinel write appended on a real tool call, confirmed, then
reverted) before being left in place — not just written and assumed to
work.

**Known limits, honestly**: both only match the `Bash` tool — a secret
surfacing via `Read` on a decrypted file isn't caught by either. The
post-use scanner's patterns are specific shapes plus this repo's two
sensitive `secrets.yaml` key names; a secret that doesn't match one of
those (a new kind of credential added later, a password with no
recognizable prefix) won't be flagged. The pre-use guard only recognizes
the `sops -d` / `/run/secrets/` shapes, not every way a secret could leak.
The sections below are what's still judgment rather than pattern-match —
read them for the cases the hooks don't cover, not as a first line of
defense that's now redundant.

## Preventing it

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

- `.claude/hooks/secrets-guard-pretooluse.sh` and
  `.claude/hooks/secrets-guard-posttooluse.sh` — the actual enforcement,
  wired in `.claude/settings.json`'s `hooks.PreToolUse`/`hooks.PostToolUse`.
  Read these before assuming a new risky-command shape is covered; if it
  isn't, extend the pattern match rather than only adding prose here.
- `CLAUDE.md`'s Safety section — why `secrets.yaml` is encrypted-but-committed
  on purpose, and which hosts are enrolled.
- `flake/modules/nire/system/secrets/sops.nix` — how secrets are declared
  and wired to services in this repo.
