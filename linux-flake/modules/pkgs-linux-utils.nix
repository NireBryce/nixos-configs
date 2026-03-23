{ self, inputs, ...}:
{ 
    flake.modules.homeManager.pkgs-linux-utils = {
        imports = [
            (inputs.import-tree ../pkgs-hm/linux-utils)

        ];
    };
}
