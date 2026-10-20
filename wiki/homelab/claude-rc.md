# Claude Remote Control on cube

_Last modified: 2026-10-20_

`claude remote-control` sessions on `nire-cube`, one per working directory,
kept running as user services so they come back after a reboot and are
reachable from claude.ai/code or the Claude mobile app. Built in
[`claude-rc-cube.nix`](../../flake/modules/host-config/cube/configuration/claude-rc-cube.nix);
its header comment has the reasoning behind each option.

## Contents

- [Quick facts](#quick-facts)
- [Day to day](#day-to-day)
- [What a session can reach](#what-a-session-can-reach)
- [Traps](#traps)
- [See also](#see-also)

## Quick facts

- **Units**: `claude-rc-<name>`, user services of elly on cube, one per entry
  in the module's `dirs` (nixos-configs, dirs-as-categories,
  flake-module-graph, launchpad). They start at boot because elly has linger
  there (`loginctl show-user elly -p Linger`).
- **Logs / state**: `systemctl --user list-units 'claude-rc-*'`,
  `journalctl --user -u claude-rc-<name>`. Each journal prints the
  `claude.ai/code?environment=...` link when it registers.
- **Add or drop a directory**: edit `dirs` in the module, switch cube. The
  directory must already have been trusted once by running `claude` in it,
  or the unit exits "Workspace not trusted" and retries every 30 seconds.
- **Push**: sessions push with sops secret `cube_claude_rc_github_token`, a
  fine-grained PAT (four repos, Contents read/write), not the account `gh`
  token. Expires 2027-01-18 (90 days):
  [maintenance-schedule](../maintenance-schedule.md) item 13 has the
  rotation steps.
- **Hand-started `claude rc` in the same directory** makes the unit fail with
  "already served by a terminal `claude remote-control`" and retry; stop the
  hand-started one first.
- **Verified** (2026-10-19, by hand on cube): all four units register with
  claude.ai after the old processes were stopped. **Not verified**: a real
  push with the real token, a reboot, and whether `~/.claude.json` survives
  claude's rewrites through the file bind mount.

## Day to day

Restart one: `systemctl --user restart claude-rc-<name>`. All of them:
`systemctl --user restart 'claude-rc-*'` (needed after rotating the token, so
the units reload the credential). A session started from the app is a child
of its unit, in a worktree of that directory.

## What a session can reach

Each unit runs with `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem=strict`
and `ProtectHome=tmpfs`, so it sees only its project directory, `~/.claude`,
`~/.claude.json`, `~/.cache` and `~/.gitconfig` (read-only). `~/.ssh` and
`~/.config/gh` do not exist inside it. `ProtectSystem=strict` alone leaves
`/home` writable on cube (tested), which is why `ProtectHome` is there.

Claude Code's Bash sandbox is separate: it is set in cube's
`~/.claude/settings.json`, which this repo does not manage (`sandbox.enabled`,
`denyRead` on `~/.ssh` and `~/.config/gh`). It covers Bash commands only; the
file tools run outside it.

## Traps

- `ProtectSystem=strict` is not a home-directory protection here.
- A NixOS `systemd.user.services` entry starts in every user's manager, hence
  `ConditionUser = "elly"` on the units.
- `LoadCredential` is read when the unit starts: a rotated token needs a unit
  restart, not just a switch.
- The git credential helper replaces `~/.gitconfig`'s `gh auth git-credential`
  for github.com through `GIT_CONFIG_*`; an empty value resets the list, a
  second value adds the helper.

## See also

- [Reaching cube's services](reaching-services.md) for ssh to cube
  (`ts-cube`, never `nire-cube`).
- [Maintenance schedule](../maintenance-schedule.md), item 13.
