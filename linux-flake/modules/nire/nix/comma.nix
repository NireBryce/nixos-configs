{ self, inputs, ...}:
{ flake.nixosModules.nix = 
{ ... }: 
{
    programs.nix-index-database.comma.enable = true;
}
;}
