{ config, inputs, withSystem, ... }:
let
    # withSystem enters flake-parts' per-system scope, which is what makes the
    # system-preselected `self'` / `inputs'` available to host modules.
    #
    # `pkgs` is deliberately NOT taken from perSystem: nixosSystem builds its own
    # from the host's own nixpkgs.config, and perSystem's default
    # legacyPackages.<system> instance has none of that applied -- taking it from
    # there would silently drop allowUnfree, which this config depends on.
    mkHost = system: hostModule: withSystem system ({ self', inputs', ... }:
        inputs.nixpkgs.lib.nixosSystem {
            specialArgs = { inherit inputs self' inputs'; };
            modules     = [ hostModule ];
        });

    # Same shape and same reasoning as mkHost -- pkgs not taken from perSystem,
    # for the same allowUnfree reason -- just calling darwinSystem instead of
    # nixosSystem. darwinSystem's own signature (nix-darwin's flake.nix) takes
    # `modules` and forwards anything else through, same as nixosSystem, so
    # `specialArgs` works identically.
    mkDarwinHost = system: hostModule: withSystem system ({ self', inputs', ... }:
        inputs.darwin.lib.darwinSystem {
            specialArgs = { inherit inputs self' inputs'; };
            modules     = [ hostModule ];
        });
in
{
    flake.nixosConfigurations = {
        nire-durandal = mkHost "x86_64-linux" config.flake.modules.nixos.durandalConfiguration;
        nire-tenacity = mkHost "x86_64-linux" config.flake.modules.nixos.tenacityConfiguration;
        nire-cube     = mkHost "x86_64-linux" config.flake.modules.nixos.cubeConfiguration;

        # nire-lego (never built or switched) and nire-installer (the generic
        # live-USB installer image) were both removed 2026-08-27 -- see
        # wiki/history.md. nire-installer's mechanism (embedded flake, patched
        # Calamares, unattended nixos-install) is not gone conceptually, just
        # not carried in this tree; nireHost/installer/liveusb-installer.md's
        # last version (git history) is the starting point if it returns.

        # nire-llm-sandbox (a libvirt VM on nire-cube sandboxing an LLM coding
        # agent) was removed 2026-08-28 -- see wiki/history.md. The generic
        # generator it was built on, VMs/_lib/libvirt-vm.nix, is kept as
        # unexercised reusable infrastructure; its last full config (git
        # history) is the starting point if a VM like it is wanted again.
    };

    flake.darwinConfigurations = {
        nire-lysithea = mkDarwinHost "aarch64-darwin" config.flake.modules.darwin.lysitheaConfiguration;
    };
}
