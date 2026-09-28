# opencode on nire-cube: the CLI, and `opencode serve` as a detachable
# backend for the user's opencode TUI sessions. Cube-only, and the only
# host with opencode at all -- lysithea has Homebrew's copy (homebrew.nix),
# nothing else does.
#
# WHY: a plain `opencode` TUI exit kills in-flight work. Under systemd the
# TUI is just a client (`opencode attach`, or `just opencode-attach`) --
# exiting detaches, sessions keep running server-side and resume with
# `-c`/`-s <id>`, across reboots.
#
# FILE PLACEMENT, 2026-09-26: moved here from
# hosts/cube/configuration/opencode-server-cube.nix (module name
# `opencode-server-cube`), and the Home Manager module
# packages/development/tools/ai-tools/opencode.nix (name `opencode`), which
# put the CLI on every host, was deleted -- an agent that can run shells as
# the user belongs on the one machine set up to host it. Category
# `coding-agent`, not `opencode`: a category and its module sharing a name
# silently MERGE. Reaches cube through the `homelab` umbrella.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { config, pkgs, lib, ... }: {
            # # description = "opencode serve: detachable TUI sessions for elly, bound tailnet-only, basic-auth";

            # PORT 3003 -- caddy.nix owns the 300x map for this host and
            # proxies the rest; this one is deliberately not behind it.

            # BASIC AUTH, 2026-09-26. Tailnet-only is not access control:
            # without OPENCODE_SERVER_PASSWORD, `opencode serve` answers
            # every request unauthenticated, and its API runs shells and
            # reads files as the user -- so every tailnet device the ACL
            # lets reach cube had a shell here. Username is `opencode`
            # (the default; `opencode attach` hardcodes it, so don't set
            # OPENCODE_SERVER_USERNAME). The sops VALUE is the bare
            # password; the template turns it into the `KEY=value` line
            # EnvironmentFile wants. Owned by the user because a USER
            # manager reads EnvironmentFile as that user, not as root the
            # way a system unit does. Clients: `just opencode-attach`
            # passes it via the environment, prompting when unset.
            sops.secrets."OPENCODE_SERVER_PASSWORD" = { };
            sops.templates."opencode-server.env" = {
                owner   = "elly";
                mode    = "0400";
                content = "OPENCODE_SERVER_PASSWORD=${config.sops.placeholder."OPENCODE_SERVER_PASSWORD"}\n";
            };

            # A systemd --user manager only runs while its user is logged in
            # WITHOUT linger, so the unit would never auto-start at boot.
            # This is the declarative form of `loginctl enable-linger elly`.
            users.users.elly.linger = true;

            # The CLI, for `opencode attach` from a shell on cube. Per-user
            # rather than systemPackages: it's the user's tool, and the
            # server's ExecStart uses the store path directly either way.
            users.users.elly.packages = [ pkgs.opencode ];

            # A user (not system) unit: the state is the user's
            # (~/.local/share), and `systemctl --user` needs no sudo, which
            # on cube wants a password. The NixOS side writes the unit
            # file; HM's systemd module is not involved.
            systemd.user.services.opencode-server = {
                description = "opencode serve -- detachable opencode sessions, tailnet-only";
                wantedBy    = [ "default.target" ];

                # TAILNET-ONLY BY BIND ADDRESS, not by firewall or proxy:
                # ExecStart resolves the tailscale IP at start and binds ONLY
                # that address, so "only reachable over tailscale" is a
                # property of the socket, not of a rule elsewhere. Needs no
                # firewall change either -- traffic over tailscale0 is already
                # trusted (networking.nix) and nothing else listens.
                #
                # Not the repo's usual loopback-behind-Caddy shape because
                # `opencode attach` speaks at the ROOT of its URL and takes a
                # bare host:port, so a path prefix would need stripping its
                # client never asks for; and per-node `tailscale serve` would
                # not survive, since tailscale-serve.service re-runs `serve
                # set-config --all` at every boot and a user unit cannot order
                # itself after a system one to reapply.
                #
                # NOT HARDENED on purpose: sessions read and edit files across
                # the user's home and run shells and build tools, so ProtectHome
                # or RestrictAddressFamilies would break the tool this exists
                # to serve. Same call sunshine.nix made. State lives in
                # ~/.local/share/opencode and needs no *-persist.nix while
                # cube has a persistent root -- a root-wiping host importing
                # this would need one first.
                serviceConfig = {
                    Type = "simple";

                    # The bind address is resolved at start -- hardcoding
                    # the 100.x address would break silently the day the
                    # tailnet reissues it. The script EXITS 1 when the
                    # lookup fails or comes back empty, so systemd retries
                    # (below): `--hostname` given an empty string makes
                    # opencode bind its default, 127.0.0.1, and start
                    # "successfully" where nothing off-host can reach it.
                    # `exec` keeps the shell from wrapping the server. The
                    # tailscaled control socket is world-connectable, so the
                    # lookup works from the user manager.
                    ExecStart = pkgs.writeShellScript "opencode-serve-tailnet" ''
                        ip=$(${lib.getExe pkgs.tailscale} ip -4) && [ -n "$ip" ] || exit 1
                        exec ${lib.getExe pkgs.opencode} serve --hostname "$ip" --port 3003
                    '';

                    # No After=/Wants= on tailscaled: the user manager
                    # cannot order against system units at all. At boot the
                    # lookup above usually runs before tailscaled answers;
                    # the exit 1 plus Restart=on-failure retries every 5s
                    # until it does. 5s apart stays under the default start
                    # limit (5 starts in 10s), so it retries indefinitely.
                    Restart    = "on-failure";
                    RestartSec = "5s";

                    # systemd --user's default PATH is thin; serve-mode
                    # sessions spawn shells, git, and build tools, which
                    # need the system and HM profiles. ExecStart itself is
                    # absolute store paths either way.
                    Environment = "PATH=/run/wrappers/bin:/etc/profiles/per-user/elly/bin:/run/current-system/sw/bin";

                    # The basic-auth password -- see BASIC AUTH above. No
                    # `-` prefix: a missing file must fail the start, not
                    # bring the server up open.
                    EnvironmentFile = config.sops.templates."opencode-server.env".path;
                };

                # NixOS systemd.user.services is GLOBAL: the unit lands in
                # /etc/systemd/user, which every user manager reads, and
                # wantedBy enables it in all of them. Without this
                # condition, sddm's manager (user@175, alive whenever the
                # greeter session is) starts its own copy; if it wins the
                # race to port 3003, the user's copy crash-loops on ServeError
                # forever and attach talks to a server running as sddm --
                # wrong cwd (/var/lib/sddm as the default project), wrong
                # state dir. Hit 2026-09-08 on cube. ConditionUser makes
                # the unit a no-op in every other user's manager.
                unitConfig.ConditionUser = "elly";
            };
        };
}

# ── history ─────────────────────────────────────────────────────────────────
#
# 2026-09-26 — until then ExecStart was `sh -c 'exec opencode serve
# --hostname $(tailscale ip -4) ...'`, with a comment claiming a failed
# lookup fails the start. It didn't: a failing `$(...)` inside the command
# line doesn't fail the command, so on the 20:34 boot (tailscaled not up
# yet) opencode got `--hostname ''`, bound 127.0.0.1, and stayed there --
# "connection refused" from every tailnet device until a manual restart.
