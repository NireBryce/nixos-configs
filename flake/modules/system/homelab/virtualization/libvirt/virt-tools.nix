{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        flake.modules.nixos.${moduleName} = { pkgs, ... }: {
            # # description = "client and disk-image tooling for the VMs libvirt.nix hosts";

            # Split from libvirt.nix so that file stays about the daemon and its
            # options. Nothing here configures libvirtd; it is all things you run
            # against it.
            #
            # `libvirt` and `qemu` themselves are deliberately absent: the libvirtd
            # module already puts cfg.package and cfg.qemu.package into
            # environment.systemPackages, so `virsh` and `qemu-img` are on PATH
            # already and listing them here would pin a second copy. `spice-gtk` is
            # out for the same reason -- virtualisation.spiceUSBRedirection in
            # libvirt.nix installs it, for the polkit actions that go with the
            # setuid spice-client-glib-usb-acl-helper wrapper.
            environment.systemPackages = with pkgs; [
                virt-viewer     # standalone SPICE/VNC console, no virt-manager needed
                virt-top        # top(1) for domains
                guestfs-tools   # virt-cat, virt-df, virt-sysprep, virt-customize
                libguestfs      # guestfish, and the library the above are built on
                quickemu        # throwaway VMs from a one-line spec, outside libvirt

                # Windows guest paravirt drivers, as an ISO to attach at install
                # time -- storage and network in a Windows guest are unusably slow
                # or absent until they are loaded. Unfree; allowUnfree is already
                # set system-side in basic-nix-settings.nix.
                virtio-win
            ];
        };
}
