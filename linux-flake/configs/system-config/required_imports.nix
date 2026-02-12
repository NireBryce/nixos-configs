{den, ...}:
let
imports = [
    den.aspects.nixos.provides.dev-tools
    den.aspects.nixos.provides.flatpak
    den.aspects.nixos.provides.font
    den.aspects.nixos.provides.gaming
    den.aspects.nixos.provides.hw-amd-cpu
    den.aspects.nixos.provides.hw-amd-gpu 
    den.aspects.nixos.provides.impermanence
    den.aspects.nixos.provides.networking
    den.aspects.nixos.provides.networking-bluetooth
    den.aspects.nixos.provides.networking-wifi
    den.aspects.nixos.provides.nix
    den.aspects.nixos.provides.peripherals
    den.aspects.nixos.provides.pkgs
    # den.aspects.nixos.provides.pkgs-brew
    # den.aspects.nixos.provides.pkgs=flatpak
    den.aspects.nixos.provides.pkgs-vscode
    den.aspects.nixos.provides.secrets
    den.aspects.nixos.provides.shells
    den.aspects.nixos.provides.sound
    den.aspects.nixos.provides.srvc-kdeconnect
    den.aspects.nixos.provides.ssh
    den.aspects.nixos.provides.system
    den.aspects.nixos.provides.system-nfs
    den.aspects.nixos.provides.users
    den.aspects.nixos.provides.virtualization
    den.aspects.nixos.provides.wayland
    den.aspects.nixos.provides.wm-kde
    den.aspects.nixos.provides.xdg-portals
];
in
{
    placeholder = imports;
}
