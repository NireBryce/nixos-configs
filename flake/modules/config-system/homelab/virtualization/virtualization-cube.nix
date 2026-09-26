# nire-cube's VM wiring -- every libvirt VM on cube is instantiated here,
# one import of VMs/_lib/libvirt-vm.nix per VM. Revives the name of the
# llm-sandbox-era wiring file (removed 2026-08-28 with that VM); the file
# is BARE in virtualization/ on purpose -- a category collects from its
# subdirectories only, so this reaches cube through `homelab`'s
# bareModulesOf sweep (wiki/categories/virtualization.md has the
# mechanism), and NOT through the shared `virtualization` aggregate,
# which is exactly why tenacity, importing `containers` but not the VM
# half, stays unaffected.
#
# The guest itself: forge-runner (deliberately NOT nire-prefixed -- that
# prefix names the fleet machines, and this is a component of cube;
# hosts.nix's entry says so) -- declared in
# hosts/forge-runner-configuration.nix and instantiated as a
# nixosConfiguration in hosts/hosts.nix -- same shape llm-sandbox used.
{ config, lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
        runnerCfg = config.flake.nixosConfigurations.forge-runner.config;
    in {
        flake.modules.nixos.${moduleName} =
            import ./VMs/_lib/libvirt-vm.nix {
                name  = "forge-runner";
                # `uuidgen` once, pinned forever -- libvirt's redefinition
                # trap is the generator's `uuid` parameter comment. No
                # libvirt has ever assigned this domain an identity, so a
                # fresh one is correct here (llm-sandbox adopted its
                # already-running UUID only because it had to).
                uuid  = "088c7844-747b-45c0-8ba1-804db641f0ea";
                image = runnerCfg.system.build.image;
                # NOT just runnerCfg.image.filePath -- that option is
                # relative to the image derivation's own $out (the trap
                # that bit llm-sandbox, lessons-learned §36).
                imagePath = "${runnerCfg.system.build.image}/${runnerCfg.image.filePath}";
                memoryMB  = 4096;
                vcpus     = 2;
                networked = true;

                # Fixed address for SSH from cube only: `ssh forge-runner` on
                # cube (actions-runner.nix's alias; the guest trusts only
                # cube's key). `sourceCidrs =
                # [ ]` keeps the DHCP reservation and forwards nothing --
                # until 2026-09-25 this forwarded host port 2223 from the
                # tailnet (`sourceCidrs = [ "100.64.0.0/10" ]`). guestId 11
                # deliberately doesn't reuse llm-sandbox's 10: stale libvirt
                # state on cube (defined domains, dhcp-host entries) outlives
                # its config, and the point of the fresh identity is never
                # meeting it. hostPort is unused with no source ranges.
                sshForward = {
                    guestId     = 11;
                    hostPort    = 2223;
                    sourceCidrs = [ ];
                };

                # What the guest can send, not receive: ~32 Mbit/s average.
                # Its uploads are pushes to the forge and job output; its
                # downloads (caches, toolchains) are unlimited.
                bandwidth = { outboundKBps = 4096; };

                # Job code runs in here, so nothing it leaves behind
                # should outlive a cube boot or a guest change -- and a
                # switch that changes the guest then reaches it with no
                # manual overlay reset (the generator's `ephemeral`
                # comment). The guest's nix store starts cold each time.
                ephemeral = true;

                # The runner's token, staged by
                # git-forge/forgejo/actions-runner.nix's registration
                # unit (a root ExecStartPost) from
                # the sops-decrypted /run/secrets copy. This is the whole
                # delivery mechanism -- the guest runs no sops and has no
                # key; see the guest configuration's header for why the
                # share's contents must stay single-purpose.
                shares = [ {
                    source = "/var/lib/forgejo-runner-share";
                    tag    = "runner-secret";
                } ];
            };
    }
