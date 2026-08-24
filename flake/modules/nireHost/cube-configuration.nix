# What nire-cube is made of. GMKtec Nucbox G11, a mini PC -- workstation
# shape, same as durandal, not a handheld (see lego/tenacity-configuration.nix
# for that shape instead).
#
# CPU: AMD Ryzen Embedded R2514, 4c/8t, max boost 3.7GHz, 4MB L3.
# GPU: AMD Radeon integrated graphics (on-die with the R2514).
# Both are plain AMD, same silicon family durandal and lego already run, so
# this host takes the shared `hardware` category (amdcpu, amdgpu) same as
# they do.
#
# This file sits directly under nireHost/ rather than in a category directory,
# because dirsAsCategory only collects from *sub*directories -- a host
# definition should not become a member of anything.
#
# Meant as a copy of durandal-configuration.nix's shape -- same category
# imports, same workstation session -- adapted for hardware that isn't
# durandal's:
#
#   - b550-suspend-fix.nix is NOT carried over. It clears PCI wakeup on two
#     specific PCI IDs (1022:1483) belonging to durandal's Gigabyte B550M
#     board's Starship/Matisse GPP bridges. The Nucbox G11 is different
#     silicon entirely (embedded SoC, not a socketed B550 board) and almost
#     certainly has different (or no) wakeup bug, so copying a PCI-ID-keyed
#     fix across to hardware it wasn't diagnosed on would be pure
#     superstition. If cube turns out to have its own suspend/wake issue,
#     diagnose it fresh and add a `cube`-specific fix the same way durandal's
#     was added, rather than assuming this one applies.
#
#   - Disk layout comes from a captured hardware-configuration, not disko.
#     cube/hardware/disko-cube.nix used to wire in
#     nire/impermanence/_disko/impermanence-luks-btrfs.nix against a
#     deliberate placeholder device, from when this host had not been
#     installed yet. It was installed by hand instead, off the stock NixOS
#     live ISO -- plain persistent btrfs root, no LUKS -- so that file was
#     deleted and replaced with cube/hardware/hardware-cube.nix, a real
#     nixos-generate-config capture. See that file's own header and history
#     note for the full story.
#
# WITHOUT impermanence, unlike durandal: this host was installed with a plain
# persistent root, not the `/root`-wipe durandal, tenacity, and lego have.
# `impermanence` is deliberately NOT in this file's imports below.
# invariants.nix's rollback, hibernation, and persistence checks are gated on
# the restore-root initrd unit existing (see its "hosts without impermanence
# opt out" header) so they don't apply here. WARN-password-required.nix fires
# its warning
# on this host for the same reason -- elly-user.nix's hashedPasswordFile still
# points at /persist/passwords/elly unconditionally, and nothing in this repo
# creates that file; it was created by hand on the real machine before this
# was ever switched to. Read WARN-impermanence.nix and README.md's safety
# section before assuming any of that has changed for cube specifically.
{ config, ... }:
{
    flake.modules.nixos.cubeConfiguration.imports =
    with config.flake.modules.nixos; [
        # ── this machine ──────────────────────────────────────────────────────
        # nireHost/cube/: hardware-cube, boot-cube, nixpkgs-hostPlatform-cube,
        # nixpkgs-stateVersion-cube -- suffixed for the same reason
        # tenacity's/lego's are: a module's name is its filename, and
        # same name in the same class merges rather than erroring.
        cube

        # ── shared ────────────────────────────────────────────────────────────
        boot            # common boot options: boot-generations

        # Deliberately NOT `impermanence` -- see the header above. This host
        # keeps a plain persistent root, not the `/root` wipe
        # durandal/tenacity/lego have.

        hardware        # amdcpu, amdgpu -- R2514 + integrated Radeon is AMD
                        # throughout, same shared category durandal and lego
                        # already import.
        nix
        peripherals
        shell-config
        system

        # Same choice durandal made: a workstation, its own session module
        # rather than the whole `desktop-env` category (which also holds
        # jovian, a handheld-only module this host has no use for).
        # kde-desktop pulls in kde-base itself.
        kde-desktop

        # libvirt/QEMU VMs: libvirt, virt-tools, vm-networking. Same choice
        # durandal made. Not imported by tenacity or lego, which is the whole
        # reason this is a category of its own instead of part of `system`.
        virtualization

        # The nire-llm-sandbox libvirt VM (Claude Code, isolated from the
        # real host) -- cube only, added 2026-08-22. NOT part of the
        # `virtualization` aggregate above, on purpose: this line is the only
        # thing that reaches it. See virtualization-cube.nix's own header for
        # why it has to be named and imported this way rather than living in
        # a normal subdirectory of nire/virtualization/.
        virtualization-cube

        # podman + distrobox. Its own category as of 2026-08-22, split out of
        # `system` the same way `virtualization` was. All four NixOS hosts
        # import this explicitly now -- no package set changed, only where
        # the module lives.
        containers

        # Prometheus + Grafana, scraping this host's own node/cadvisor/libvirt
        # exporters -- node-exporter, cadvisor, libvirt-exporter, prometheus,
        # grafana. cube-only for now, added 2026-08-23, same reasoning
        # `virtualization` got its own category for: nothing here belongs on
        # the handhelds. Grafana is reachable over Tailscale (tailscale0 is
        # trusted at the firewall, see networking.nix) and nowhere else --
        # everything upstream of it stays on loopback. See grafana.nix's
        # header for the exact mechanism and its caveats.
        monitoring

        # Forgejo, a self-hosted git forge -- cube-only, added 2026-08-24,
        # same "nothing here belongs on the handhelds" reasoning as
        # `monitoring` just above. Reachable over Tailscale only, exactly
        # the same trustedInterfaces mechanism Grafana uses -- see
        # forgejo.nix's own header for the mechanism and the two runtime
        # traps (secret handling, tailnet device-name) it deliberately
        # avoids by not repeating grafana.nix's/tailscale.nix's own history.
        # Category is named `git-forge`, NOT `forgejo` -- a category and its
        # own single module both named `forgejo` would declare the same
        # `flake.modules.nixos.forgejo` attribute and silently merge, the
        # exact `containers`/`podman.nix` collision CLAUDE.md's Architecture
        # section already warns about, hit for real writing this and caught
        # by `just modules` before it shipped.
        git-forge

        # golink, tailscale's `go/foo` shortlink service -- cube-only, added
        # 2026-08-24, own category (`shortlinks`) for the same "nothing here
        # belongs on the handhelds" reason `monitoring` and `git-forge` above
        # each got one. Unlike those two, this one is NOT reached at
        # nire-cube's own address and needs no firewall consideration at all:
        # golink embeds tsnet, so it joins the tailnet as its own separate
        # device (named `go`, which is what makes `http://go/` resolve) and
        # listens only there. Needs a ONE-TIME interactive login on first
        # start -- `journalctl -u golink -f`, open the printed URL -- because
        # no TS_AUTHKEY is wired in, the same call tailscale.nix makes for
        # the host daemon. See golink.nix's own header for all of it.
        # Category is `shortlinks`, not `golink`, for the same
        # category/module name-collision reason `git-forge` isn't `forgejo`.
        shortlinks

        # ── packages ──────────────────────────────────────────────────────────
        # Full parity with durandal.
        development
        editors
        gui-other
        linux-utils
        nix-utils
        shell-apps
        terminals

        # ── user ──────────────────────────────────────────────────────────────
        elly            # elly-user: the account, groups, emergency packages
    ];

    flake.modules.nixos.cubeConfiguration.networking.hostName = "nire-cube";
}
