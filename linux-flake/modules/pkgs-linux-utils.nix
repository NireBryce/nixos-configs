{ config, inputs, ... }:
{ 
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.pkgs-linux-utils ];

    flake.modules.homeManager.pkgs-linux-utils = {
        imports = [
            (inputs.import-tree ../pkgs-hm/linux-utils)

        ];
    };
}
