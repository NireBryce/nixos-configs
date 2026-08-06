{ config, inputs, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.pkgs-gui ];

    flake.modules.homeManager.pkgs-gui = {
        imports = [
            (inputs.import-tree ../pkgs-hm/pkgs-gui)
        ];
    };

}
