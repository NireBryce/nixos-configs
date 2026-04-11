{ nirePackages, lib, ... }: 
{
    nirePackages.nix-utils.provides.all = { 
        # include sub-aspects when you use the generic
        # https://github.com/Gwenodai/nixos/blob/main/modules/programs/cli%20%5BHU%5D/!includes.nix
        includes = lib.attrValues nirePackages.nix-utils._;
    };
}

