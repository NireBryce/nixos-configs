{ self, inputs, ...}:
{ 
    flake.homeModules.pkgs-linux-utils = {
        imports = [
            (inputs.import-tree ../pkgs-hm/linux-utils)

        ];
    };
}
