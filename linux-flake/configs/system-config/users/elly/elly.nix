{
    pkgs,
    ...
}:
{
den.bundles.users.elly = { ... }: 
{
    users.mutableUsers = false;
    users.users = { 
        elly = {
            shell                 = pkgs.bash;
            isNormalUser          = true;
            extraGroups           = [ "wheel" "audio" "podman" ]; # Enable ‘sudo’ and deeper audio access
            hashedPasswordFile    = "/persist/passwords/elly";
            packages  = with pkgs; [ 
                # Emergency packages if home-manager dies
                firefox
                git
                gh
                micro
                tree
                kdePackages.partitionmanager
            ];
        };
    };
}
;}
