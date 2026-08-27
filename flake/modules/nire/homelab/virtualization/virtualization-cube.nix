# Cube-only addition to `virtualization`, NOT a member of the category
# itself -- and that distinction is load-bearing, not a style choice.
#
# Sits bare in nire/virtualization/, deliberately not inside VMs/ or any
# other subdirectory. dirsAsCategory (this directory's own copy) only
# collects modules from *sub*directories -- a .nix file sitting directly in
# a category directory is collected by nothing, the same rule
# flake/doc/dirsAsCategory.md documents and CLAUDE.md restates. That means
# this file never becomes part of `flake.modules.nixos.virtualization`, so
# importing `virtualization` (as durandal and cube both do) does not reach
# it -- only importing `virtualization-cube` by its own name does, which is
# exactly one line in cube-configuration.nix and nowhere else.
#
# This is the opposite placement from VMs/_lib/libvirt-vm.nix (the generator
# this file calls), which sits under `_lib/` specifically because it is a
# plain function import-tree cannot handle at all, not because it needed to
# be excluded from the aggregate. See that file's own header for the
# distinction and why VMs/ itself is a real subdirectory -- the generator
# genuinely lives there, per the original ask, even though the module that
# calls it does not.
#
# Verified further than plain evaluation, as of 2026-08-22 -- see
# llm-sandbox-configuration.nix's header for exactly what that does and
# doesn't cover. Still short of a real libvirt define/boot on hardware.
{ config, lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);

        # The guest's own evaluated config, read directly rather than through
        # any packages/flake-output indirection -- see
        # llm-sandbox-configuration.nix's header for why. `image` and
        # `imagePath` both come off this one value, so they can never
        # disagree with each other the way two separately-derived references
        # could.
        sandboxCfg = config.flake.nixosConfigurations.nire-llm-sandbox.config;
    in {
        flake.modules.nixos.${moduleName} =
            import ./VMs/_lib/libvirt-vm.nix {
                name  = "llm-sandbox";

                # The UUID libvirt itself assigned when `virsh define` first
                # succeeded on nire-cube, 2026-08-23 -- adopted here rather
                # than a fresh `uuidgen` because the domain was already
                # running under it by the time this generator gained a
                # `uuid` parameter (see libvirt-vm.nix's own comment on that
                # parameter for why one is required at all); picking a new
                # UUID here would make this same define-conflict fire again
                # on the next switch, against the guest that's already up.
                uuid  = "4da8f257-fad8-4670-ab2d-7577ca94d5ed";

                image = sandboxCfg.system.build.image;

                # NOT just sandboxCfg.image.filePath -- that option is
                # documented as relative to the image derivation's own $out,
                # not an absolute in-store path by itself. Missed that
                # reading the docs the first time; caught by actually
                # building the activation script and finding it checking
                # `[ -e "nixos-image-qcow2-....qcow2" ]` (a bare filename,
                # cwd-relative and certain to fail under systemd) instead of
                # a real path. `${...}/${...}` here is what combines them.
                imagePath = "${sandboxCfg.system.build.image}/${sandboxCfg.image.filePath}";

                memoryMB  = 4096;
                vcpus     = 2;

                # NAT internet access. See libvirt-vm.nix's own parameter
                # comment: this isn't only a security knob -- the agent
                # inside needs network to reach Claude's API at all, so
                # `false` produces a VM that boots but can't do the one
                # thing it exists for. Left toggleable here (not hardcoded
                # into the generator) because the isolation/functionality
                # tradeoff is a real, live decision, not a fixed default.
                networked = true;

                # SSH into the sandbox from off-host, tailnet only -- NOT
                # LAN too. Added 2026-08-23. The guest side was already
                # fully ready for this (llm-sandbox-configuration.nix has
                # had `services.openssh.enable` and elly's authorized keys
                # from the start); this is what actually opens a path in.
                # `sourceCidrs = tailnetOnlyCidrs` overrides
                # libvirt-vm.nix's own default (LAN-or-tailnet) down to
                # tailnet-only, a deliberate choice for this VM
                # specifically -- not a property of the generator. `10` and
                # `2222` are this generator's first real allocation; if a
                # second VM ever wants sshForward too, it needs its own
                # `guestId` (no auto-allocator -- see libvirt-vm.nix's
                # parameter comment) and its own `hostPort`.
                sshForward = {
                    guestId     = 10;
                    hostPort    = 2222;
                    sourceCidrs = [ "100.64.0.0/10" ]; # tailnetOnlyCidrs, inlined:
                                                        # this file has no `let`
                                                        # binding reaching into
                                                        # libvirt-vm.nix's own
                                                        # internals to name it by.
                };
            };
}
