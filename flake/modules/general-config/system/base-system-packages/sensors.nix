# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            lm_sensors # lm_sensors
        ];
    };
}
