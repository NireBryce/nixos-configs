# Commit signing through the SSH agent

_Last modified: 2026-11-21_

Every commit and tag is SSH-signed. `signing.key` in
`flake/modules/users-config/elly/elly-git/elly-git.nix` is a public key; the
private half stays in the Bitwarden desktop app, which serves it from its SSH
agent on `~/.bitwarden-ssh-agent.sock` and shows an approval dialog for each
request. This page covers what git runs to sign, what it prints when signing
fails, and the one-time cleanup of the older setup.

## Contents

- [Quick facts](#quick-facts)
- [What the failure line means](#what-the-failure-line-means)
- [The older setup and its cleanup](#the-older-setup-and-its-cleanup)
- [Checking it works](#checking-it-works)

## Quick facts

- Git signs through `gpg.ssh.program`, set in `elly-git.nix` to a store-path
  script named `git-ssh-sign`. It replaces `ssh-keygen` in git's call.
- The script points `SSH_AUTH_SOCK` at the agent socket when it is unset and
  the socket exists, runs `ssh-keygen` by store path, and exits with
  `ssh-keygen`'s own status. It prints nothing on success.
- When `ssh-keygen -Y sign` fails it prints one fixed line on stderr starting
  `git-ssh-sign:`. Verification calls (`git log --show-signature`) never get
  the line.
- A repo-local `gpg.ssh.program` in `.git/config` overrides the global one and
  bypasses the script. `just retire-old-ssh-sign` removes the one the old
  hand-made script needed.
- Never turn signing off to get past a failure.
- `nire-cube` has no agent: its commits sign with a key file and ask for the
  passphrase on the terminal (see [elly](../config-structure/categories/elly.md)).

## What the failure line means

The line says `ssh-keygen` returned no signature, and that the request may
have been denied or timed out, or that a key passphrase was not entered. It
cannot say which: `ssh-keygen` does not tell the script, and the script does
not read `ssh-keygen`'s output. The line is a fixed string, with no arguments
or environment in it, because agents read it.

Each signing attempt can open a new approval dialog. After a failure, tell the
user and wait for them to approve in the app; repeating the commit opens
another dialog each time.

`SSH_AUTH_SOCK` unset is a separate failure with git's own message,
`error: Couldn't get agent socket?`. The script avoids it when the socket
exists, so it means the app is not running or its agent is off.

## The older setup and its cleanup

Before the store-path script, a hand-made `~/.config/git/ssh-sign` did the
`SSH_AUTH_SOCK` step, wired in by `gpg.ssh.program` in a repo's own
`.git/config`. Repo-local config wins over the global setting, so that entry
keeps the old script in use after `elly-git.nix` changes, and the new one never
runs there.

`just retire-old-ssh-sign` removes it:

```sh
just retire-old-ssh-sign                        # dry run: reports, changes nothing
just retire-old-ssh-sign --apply                # unsets the override
just retire-old-ssh-sign --apply --remove-script  # also deletes the old script
```

- It unsets `gpg.ssh.program` only when the value is exactly
  `~/.config/git/ssh-sign`. Any other value is reported and left alone.
- `--remove-script` deletes the old script unless a repo you named still points
  at it. It does not search for repos you did not name; pass them as arguments.
- The repo defaults to the one the script lives in. Worktrees share their
  repo's `.git/config`, so naming one covers all of them.
- Run it once per checkout that has the override, after a switch that installs
  the new script. Before that switch, signing from a non-interactive shell would
  fall back to plain `ssh-keygen` and fail without `SSH_AUTH_SOCK`.

The recipe and its tests are `flake/scripts/retire-old-ssh-sign.sh` and
`flake/scripts/tests/test_retire_old_ssh_sign.py`.

## Checking it works

```sh
git config --show-origin --get gpg.ssh.program   # global path, not a repo-local one
git commit --allow-empty -m "signing check"       # needs the approval dialog
git log --show-signature -1                       # verifies the signature
```

If the first command names `.git/config` as the origin, the override is still
in place.
