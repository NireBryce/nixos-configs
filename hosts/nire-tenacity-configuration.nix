{
    inputs,
    ...
}:
{
    imports = [
        (inputs.import-tree ./nire-tenacity)
        (inputs.import-tree ../system-config/users/elly)
        (inputs.import-tree ../system-config/hw/gpu/amd)
        (inputs.import-tree ../system-config/hw/cpu/amd)
        (inputs.import-tree ../system-config/common)
        (inputs.import-tree ../system-config/gaming)
        (inputs.import-tree ../system-config/wm/kde)
        (inputs.import-tree ../system-config/wm/gaming-handheld)


        # impermanence
        # ____________________________________________________ 
        # |- /!!\ WARN: this will delete /root on boot /!!\ -|
        # ----------------------------------------------------
        ../system-config/impermanence/_WARN.impermanence.nix
    ];

    system.stateVersion = "25.05"; # Don't change. https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion
    networking.hostName = "nire-tenacity";
}
