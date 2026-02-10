{
    ...
}:
{
den.bundles.nix-packages = { ... }:  
{
    programs.nh = {
        enable          = true;
        clean.enable    = true;
        clean.extraArgs = "--keep-since 7d --keep 5";
        flake           = "/home/elly/nixos"; # TODO: see if this can be dynamically set to this flake's path
    };
}
;}
