# Module file: named after this file; why it looks this way: wiki/module-files.md
# One `claude remote-control` per working directory, as a user service on cube,
# so the sessions listed in claude.ai/code come back after a reboot instead of
# needing someone to ssh in and start each by hand; added 2026-10-19.
#
# These are the four directories `claude rc` was running in on cube when this
# was added. Add or drop a directory by editing `dirs`; the attribute name
# is the unit instance (`claude-rc-<name>`), the value is relative to $HOME.
#
# Runs without a TTY (checked on cube with systemd-run --user). It does refuse
# a directory whose workspace-trust dialog was never accepted ("Workspace not
# trusted ... run `claude` in <dir> first"), exits 1, and the unit retries
# every 30 seconds until someone runs `claude` there once.
#
# User services start at boot only because elly has linger enabled on cube
# (`loginctl show-user elly -p Linger`); without it they'd start at login.
# Hardening: NoNewPrivileges, PrivateTmp, ProtectSystem=strict. strict leaves
# /home writable on cube (tested with systemd-run --user), so ProtectHome=tmpfs
# empties it and BindPaths puts back only the project directory, ~/.claude,
# ~/.claude.json, ~/.cache, and ~/.gitconfig read-only. ~/.ssh and
# ~/.config/gh are therefore absent: every remote here is https through
# `gh auth git-credential`, so sessions can't push -- bind ~/.config/gh to
# change that. Tested by hand with systemd-run on cube: git, the project dir
# and `claude -p` work; whether ~/.claude.json survives claude's rewrites of
# it through a file bind mount is unchecked. The Bash sandbox in
# ~/.claude/settings.json (not managed here) layers on top; bwrap works inside.
# ConditionUser keeps it out of other users' managers (NixOS user units start
# in every one). PATH is the per-user profile plus the system one, so spawned sessions find
# git and the rest as an ssh shell would.
let
    dirs = {
        nixos-configs     = "nixos-configs";
        dirs-as-categories = "projects/nix/dirs-as-categories";
        flake-module-graph = "projects/nix/flake-module-graph";
        launchpad         = "projects/launchpad";
    };
in
{
    nixos = { lib, pkgs, ... }: {
    systemd.user.services = lib.mapAttrs' (name: dir:
        lib.nameValuePair "claude-rc-${name}" {
            description = "claude remote-control in ~/${dir}";
            wantedBy    = [ "default.target" ];
            path        = [ "/etc/profiles/per-user/elly" "/run/current-system/sw" ];
            unitConfig.ConditionUser = "elly";
            serviceConfig = {
                WorkingDirectory = "%h/${dir}";
                ExecStart        = "${lib.getExe pkgs.claude-code} remote-control";
                Restart          = "always";
                RestartSec       = 30;
                NoNewPrivileges  = true;
                PrivateTmp       = true;
                ProtectSystem    = "strict";
                ProtectHome      = "tmpfs";
                BindPaths        = [
                    "%h/${dir}" "%h/.claude" "%h/.claude.json" "%h/.cache"
                ];
                BindReadOnlyPaths = [ "%h/.gitconfig" ];
            };
        }
    ) dirs;
    };
}
