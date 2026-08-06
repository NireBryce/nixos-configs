{ config, inputs, ... }:
{
    flake.modules.homeManager.ellyHomeManager.imports = [ config.flake.modules.homeManager.pkgs-cli ];

    flake.modules.homeManager.pkgs-cli = {
        imports = [
            (inputs.import-tree ../pkgs-hm/pkgs-cli)
        ];
    };

}
