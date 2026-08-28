# golink: tailscale's `go/foo` shortlink service, run as its OWN node on the
# tailnet. Added 2026-08-24, cube-only, own category (`nire/shortlinks/`) --
# the category-as-optionality mechanism CLAUDE.md's Architecture section
# gives `monitoring` and `virtualization`; nothing here for the handhelds,
# and durandal has not asked for it.
#
# Named `shortlinks`, not `golink`: a category and its one module both named
# `golink` would declare the same `flake.modules.nixos.golink` attribute and
# silently MERGE (the `containers`/`podman.nix` collision CLAUDE.md
# documents). Not `golinks` either -- one letter from the module name reads
# as a typo later.
#
# THERE IS NO `services.golink` IN NIXPKGS (checked pinned nixpkgs rev
# e4bae1bd, 2026-01-16: `pkgs/by-name/go/golink/` exists, `nixos/modules/`
# has nothing golink-shaped). Hence the hand-written systemd unit, unlike
# forgejo.nix/grafana.nix. If nixpkgs ever grows `services.golink`, delete
# this unit and use it.
#
# NOT A SERVICE ON THIS HOST'S NETWORK: golink embeds tsnet and joins the
# tailnet as a SEPARATE DEVICE with its own tailnet IP; `:80`/`:443` listen
# on that device, not on nire-cube. Unlike grafana.nix and forgejo.nix:
#
#   - No firewall change of any kind -- no allowedTCPPorts, no
#     `trustedInterfaces`; nothing arrives at nire-cube's firewall, and it
#     is not LAN-reachable because it does not listen there.
#   - No dependency on the host's `tailscaled` (system/networking/
#     tailscale.nix): tsnet is a userspace WireGuard node in-process,
#     talking to the coordination server itself -- no host tunnel, no
#     `tailscale0`, no /dev/net/tun. `after` is `network-online.target`,
#     deliberately not `tailscaled.service`.
#   - It consumes a tailnet device slot and the tailnet ACL applies to it.
#     Per tailscale.nix's "TWO REAL TRAPS": an ACL without member-to-member
#     traffic silently drops connections here too, nothing in this repo to
#     fix.
#
# FIRST RUN NEEDS A ONE-TIME LOGIN, BY DESIGN. No `TS_AUTHKEY` -- same call
# as tailscale.nix's not wiring `authKeyFile`: keys expire (90 days max),
# so a baked-in key just buys later boot failures. Without a key tsnet
# prints an auth URL and waits. From tsnet v1.96.1 source
# (`printAuthURLLoop`, tsnet/tsnet.go; golink sets `Logf`, not `UserLogf`,
# so it logs via `log.Printf`): the URL lands on stderr/journal WITHOUT
# `-verbose`. First time:
#
#     journalctl -u golink -f      # then open the printed URL, once
#
# tsnet persists its node key in the config-dir below and reauthenticates
# from it every later boot -- once per machine, like `sudo tailscale up`.
# (tsnet.go logs "Authkey is set; but state is X. Ignoring authkey" when
# state exists -- an expired wired-in key wouldn't break an authenticated
# node. Still no reason to wire one.) To revisit: mint a key, add
# `sops.secrets.tailscale_key` in system/secrets/sops.nix (nothing declares
# it today; secrets.yaml carries an unused stale one), pass as
# `EnvironmentFile` with `TS_AUTHKEY=`.
#
# THE NODE MUST BE NAMED `go` -- a claim about the Tailscale admin console,
# not this file. `-hostname go` is what tsnet registers as, which is what
# makes MagicDNS answer `http://go/`. This tailnet renames devices
# (`nire-cube` host = `ts-cube` device, fleet-wide -- tailscale.nix's trap
# #1); renaming THIS one to `ts-go` for consistency would stop `go/foo`
# resolving. Leave it `go`.
#
# STATUS: FAILED its first real switch (nire-cube, 2026-08-24, gen 13) --
# missing AF_NETLINK, see the RestrictAddressFamilies comment below
# (lessons-learned.md §37 class: invisible to eval and to the rendered
# unit). Written from darwin (no x86_64-linux build possible, no remote
# builder -- CLAUDE.md's State section), shipped evaluates-only, and broke
# for the one thing its hardening comment meant to avoid. Lesson: not
# "harden less" -- an unexercisable hardening knob is untested however
# well-understood. Fix IS runtime-verified (A/B under `systemd-run --user`
# on the host, same binary/knobs, differing only in AF_NETLINK). Unverified
# 2026-08-24: the authenticated node -- the one-time login above must
# actually happen.
{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # StateDirectory = "golink" under DynamicUser: real directory
        # /var/lib/private/golink, symlinked from /var/lib/golink; both work
        # from outside, the service sees /var/lib/golink. Written out rather
        # than `%S` so the flags below read as ordinary paths.
        stateDir = "/var/lib/golink";
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # `pkgs` bound on the INNER NixOS module, not the outer
            # flake-parts function -- flake-parts injects no `pkgs` there;
            # evaluating it errors "attribute 'pkgs' missing". Same pattern
            # grafana.nix and zsh.nix use.

            # Unit name written out literally, NOT derived from `moduleName`:
            # the flake-parts attribute must track the filename (how
            # dirsAsCategory finds it), but the unit name keys `systemctl
            # status golink` and the journal, and should not quietly change
            # if this file is renamed.
            systemd.services.golink = {
                description = "golink -- go/ shortlinks, as its own tailnet node";
                wantedBy    = [ "multi-user.target" ];
                after       = [ "network-online.target" ];
                wants       = [ "network-online.target" ];
                # NOT after tailscaled.service -- see header.

                serviceConfig = {
                    # `-sqlitedb` is REQUIRED: golink.go exits
                    # "--sqlitedb is required" unless `-dev-listen` is set.
                    # `-config-dir` is tsnet's node-key store -- unset, it
                    # derives from os.UserConfigDir, an implicit path that
                    # goes wrong quietly under DynamicUser (no $HOME). Both
                    # pinned.
                    ExecStart = lib.concatStringsSep " " [
                        (lib.getExe pkgs.golink)
                        "-hostname go"                      # see header: must stay `go`
                        "-sqlitedb ${stateDir}/golink.db"   # the links themselves
                        "-config-dir ${stateDir}/tsnet"     # tsnet node key + state
                    ];

                    Restart    = "on-failure";
                    RestartSec = "5s";

                    # DynamicUser rather than users.users.golink: systemd
                    # owns the uid AND the state directory's ownership --
                    # exactly what went wrong twice for grafana.nix (secret
                    # file left root:root, unreadable by the service user;
                    # the hand fix regressed once). Nothing here is
                    # hand-created, so nothing to get ownership of wrong.
                    #
                    # Switching to a static user does NOT move existing
                    # state: /var/lib/private/golink would keep a dead uid,
                    # and golink would come up brand-new, unauthenticated,
                    # linkless. Move the directory and chown it in the same
                    # change.
                    DynamicUser        = true;
                    StateDirectory     = "golink";
                    StateDirectoryMode = "0700";
                    WorkingDirectory   = stateDir;

                    # Modest hardening, deliberately: DynamicUser already
                    # implies NoNewPrivileges, ProtectSystem=strict,
                    # PrivateTmp, RemoveIPC; these are the obviously safe few
                    # for a pure-Go daemon with no cgo (modernc.org/sqlite)
                    # and no device access (tsnet is a userspace netstack,
                    # never opens /dev/net/tun). MemoryDenyWriteExecute and
                    # SystemCallFilter left OUT on purpose -- an untested
                    # syscall filter fails as a confusing start crash; the
                    # knob that actually carried risk was AF_NETLINK, next
                    # comment.
                    ProtectHome           = true;
                    ProtectKernelTunables = true;
                    ProtectKernelModules  = true;
                    ProtectControlGroups  = true;

                    # AF_NETLINK IS LOAD-BEARING. Leaving it out crash-looped
                    # the first real switch (nire-cube, 2026-08-24, gen 13):
                    #
                    #   tsnet: route ip+net: netlinkrib: address family not
                    #   supported by protocol
                    #
                    # Go's `net` enumerates interfaces/routes via a netlink
                    # socket (syscall.NetlinkRIB -> socket(AF_NETLINK,
                    # SOCK_RAW, ...)); RestrictAddressFamilies makes a
                    # blocked socket() return EAFNOSUPPORT -- that message
                    # verbatim. It names netlink but reads as a
                    # kernel/protocol problem, not a sandbox one: nothing in
                    # it says "systemd". A/B-confirmed on the real host
                    # (`systemd-run --user`, same binary/knobs, differing
                    # only in this list). Anything tsnet-based needs this;
                    # do not "tidy" it back out.
                    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
                    RestrictNamespaces      = true;
                    LockPersonality         = true;
                };
            };

            # No golink-persist.nix, same reasoning as grafana.nix and
            # forgejo.nix: cube has a plain persistent root
            # (cube-configuration.nix's header), not the `/root` wipe
            # durandal/tenacity/lego get, so /var/lib/private/golink (links
            # database AND tsnet node key) survives reboots. If a host that
            # DOES wipe root ever imports this, add one first, modeled on
            # tailscale-persist.nix -- else every reboot loses every
            # shortlink and re-registers a fresh tailnet device.
        };
}
