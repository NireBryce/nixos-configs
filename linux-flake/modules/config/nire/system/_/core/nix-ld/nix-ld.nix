{
    description = "nix-ld, needed for VSCode remote connection, etc";

    nixos = 
    { lib, ... }:
    {
        programs.nix-ld.enable = lib.mkDefault true;
    };
}
