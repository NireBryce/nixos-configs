# opencode serve, as a detachable backend for elly's opencode TUI sessions --
# cube-only, filed next to cube's other host-specific config.
#
# WHY: a plain `opencode` TUI exit kills in-flight work. Under systemd the
# TUI is just a client (`opencode attach`, or `just opencode-attach`) --
# exiting detaches, sessions keep running server-side and resume with
# `-c`/`-s <id>`, across reboots.
#
# FILE PLACEMENT: hosts/cube/configuration/ is collected by the `cube`
# category from its subdirectory -- there is no import line, adding the file
# IS the wiring, and the `-cube` suffix follows this directory's convention
# (a module's name is its filename, and same-name modules merge silently
# rather than erroring). Deliberately NOT a `system/homelab/` service: one
# personal dev tool for one user, not part of the self-hosted stack, so no
# Caddy route and no wiki/categories/ page.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, lib, ... }: {
            # # description = "opencode serve: detachable TUI sessions for elly, bound tailnet-only";

            # PORT 3003 -- caddy.nix owns the 300x map for this host and
            # proxies the rest; this one is deliberately not behind it.

            # A systemd --user manager only runs while its user is logged in
            # WITHOUT linger, so the unit would never auto-start at boot.
            # This is the declarative form of `loginctl enable-linger elly`.
            users.users.elly.linger = true;

            # A user (not system) unit: the state is elly's
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
                # elly's home and run shells and build tools, so ProtectHome
                # or RestrictAddressFamilies would break the tool this exists
                # to serve. Same call sunshine.nix made. State lives in
                # ~/.local/share/opencode and needs no *-persist.nix while
                # cube has a persistent root -- a root-wiping host importing
                # this would need one first.
                serviceConfig = {
                    Type = "simple";

                    # The sh -c is load-bearing: ExecStart does no command
                    # substitution, and the bind address has to be resolved
                    # at start -- hardcoding the 100.x address here would
                    # break silently the day the tailnet reissues it.
                    # `exec` keeps the shell from wrapping the server
                    # process. The tailscaled control socket is
                    # world-connectable, so this works from the user
                    # manager (verified: `tailscale ip -4` as elly on cube).
                    ExecStart = "${pkgs.runtimeShell} -c 'exec ${lib.getExe pkgs.opencode} serve --hostname $(${lib.getExe pkgs.tailscale} ip -4) --port 3003'";

                    # No After=/Wants= on tailscaled: the user manager
                    # cannot order against system units at all. If the
                    # `tailscale ip -4` above runs before tailscaled is
                    # answering, ExecStart fails -- Restart=on-failure
                    # retries every 5s until it isn't.
                    Restart    = "on-failure";
                    RestartSec = "5s";

                    # systemd --user's default PATH is thin; serve-mode
                    # sessions spawn shells, git, and build tools, which
                    # need the system and HM profiles. ExecStart itself is
                    # absolute store paths either way.
                    Environment = "PATH=/run/wrappers/bin:/etc/profiles/per-user/elly/bin:/run/current-system/sw/bin";
                };

                # NixOS systemd.user.services is GLOBAL: the unit lands in
                # /etc/systemd/user, which every user manager reads, and
                # wantedBy enables it in all of them. Without this
                # condition, sddm's manager (user@175, alive whenever the
                # greeter session is) starts its own copy; if it wins the
                # race to port 3003, elly's copy crash-loops on ServeError
                # forever and attach talks to a server running as sddm --
                # wrong cwd (/var/lib/sddm as the default project), wrong
                # state dir. Hit 2026-09-08 on cube. ConditionUser makes
                # the unit a no-op in every other user's manager.
                unitConfig.ConditionUser = "elly";
            };
        };
}
