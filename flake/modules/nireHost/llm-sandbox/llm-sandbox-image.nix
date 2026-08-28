# Turns nire-llm-sandbox's `system.build.qcow` into a flake package, so
# `nix build .#llm-sandbox-vm` produces the actual qcow2 libvirt boots,
# without anyone needing to know the nixosConfigurations attribute path by
# heart. Image-build glue like this lives beside its host's
# -configuration.nix (llm-sandbox-configuration.nix, right next to this file)
# rather than split across modules/scripts the way most of this repo is.
{ config, lib, ... }:
{
    perSystem = { system, ... }:
    {
        # x86_64-linux only -- nire-llm-sandbox is an x86_64-linux
        # nixosConfiguration; there is no remote builder or binfmt from
        # aarch64-darwin to build it with.
        packages = lib.optionalAttrs (system == "x86_64-linux") {
            # A human-facing convenience (`nix build .#llm-sandbox-vm`) --
            # not what VMs/_lib/libvirt-vm.nix actually consumes.
            # virtualization-cube.nix reads this exact same
            # config.system.build.image value directly off
            # config.flake.nixosConfigurations.nire-llm-sandbox.config, so
            # there is one path to this derivation, not two that could drift
            # apart.
            llm-sandbox-vm =
                config.flake.nixosConfigurations.nire-llm-sandbox.config.system.build.image;
        };
    };
}
