{
    ...
}:
{ den.aspects.nixos.provides.jovian = 
{ pkgs, config, ... }: 
{
    environment.systemPackages = with pkgs; [
        adjustor
    ];


    # needed for tdp adjustor
    boot.extraModulePackages = [ config.boot.kernelPackages.acpi_call ];

    services.handheld-daemon = {
    # if you're coming here from github search looking for ways to make HHD work,
    #     I need you to understand that the TDP control is currently mired in nixpkgs
    #     if you want it to work, it needs some work that I cannot do.
    #     https://github.com/NixOS/nixpkgs/pull/347279
        enable      = true;
        user        = "elly"; # TODO: use flake-parts to make this declared centrally
        ui.enable   = true;
        adjustor = {
            enable = true;
            loadAcpiCallModule = true;
        };

    };

    systemd.services."power-profiles-daemon" = {
        enable = false; # conflicts with adjustor in hhd
    };

}
;}
