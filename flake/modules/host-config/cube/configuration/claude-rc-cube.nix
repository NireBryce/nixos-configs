# This is a dirs-as-categories module, which means it creates a flake-parts
# module that derives its name from its filename minus the .nix suffix, whose
# category module is the name of the folder it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: One `claude remote-control` per working directory, as a user service on cube,
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
# ~/.config/gh are absent: the latter holds the account-wide `gh` token
# (scopes repo, workflow, read:org, gist).
#
# Push access is a separate fine-grained token, sops secret
# `cube_claude_rc_github_token`: Contents read/write on the four repos in
# `dirs`, nothing else, 90-day expiry (wiki/maintenance-schedule.md). Each unit
# gets it through LoadCredential, and `credential.https://github.com.helper` is
# replaced, through GIT_CONFIG_* so ~/.gitconfig's `gh auth git-credential` is
# reset and not merely preceded, by a helper that prints it. If the token
# expires, pushes fail with an auth error; nothing else breaks. Tested on cube
# with a dummy token under systemd-run (LoadCredential in a user unit, helper
# chosen by `git credential fill`); the real token only exists there after a
# switch. A sandboxed Bash command may be able to read the credentials
# directory: the sandbox denyRead in ~/.claude/settings.json (not managed here)
# names ~/.ssh and ~/.config/gh only.
#
# Whether ~/.claude.json survives claude's rewrites of it through a file bind
# mount is unchecked. bwrap works inside these options.
# ConditionUser keeps it out of other users' managers (NixOS user units start
# in every one). PATH is the per-user profile plus the system one, so spawned
# sessions find git and the rest as an ssh shell would.
let
    dirs = {
        nixos-configs     = "nixos-configs";
        dirs-as-categories = "projects/nix/dirs-as-categories";
        flake-module-graph = "projects/nix/flake-module-graph";
        launchpad         = "projects/launchpad";
    };
in
{
    nixos = { config, lib, pkgs, ... }:
    let
        # Answers `get` with the unit's credential and ignores store/erase.
        tokenHelper = pkgs.writeShellScript "git-credential-claude-rc" ''
            [ "$1" = get ] || exit 0
            printf 'username=x-access-token\npassword=%s\n' \
                "$(cat "$CREDENTIALS_DIRECTORY/github-token")"
        '';
    in {
    # Owned by elly: the user units read it, root's sops activation writes it.
    sops.secrets.cube_claude_rc_github_token.owner = "elly";

    systemd.user.services = lib.mapAttrs' (name: dir:
        lib.nameValuePair "claude-rc-${name}" {
            description = "claude remote-control in ~/${dir}";
            wantedBy    = [ "default.target" ];
            path        = [ "/etc/profiles/per-user/elly" "/run/current-system/sw" ];
            unitConfig.ConditionUser = "elly";
            environment = {
                GIT_CONFIG_COUNT   = "2";
                GIT_CONFIG_KEY_0   = "credential.https://github.com.helper";
                GIT_CONFIG_VALUE_0 = "";
                GIT_CONFIG_KEY_1   = "credential.https://github.com.helper";
                GIT_CONFIG_VALUE_1 = "${tokenHelper}";
            };
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
                LoadCredential    = "github-token:${config.sops.secrets.cube_claude_rc_github_token.path}";
            };
        }
    ) dirs;
    };
}
