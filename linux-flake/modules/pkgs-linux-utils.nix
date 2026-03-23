{ self, inputs, ...}:
{ 
    flake.homeModules.pkgs-linux-utils = {
        imports = [
            (inputs.import-tree ../packages/pkgs-hm/linux-utils)

        ];
    };
    flake.nixosModules.pkgs-linux-utils = {
        imports = [
            (inputs.import-tree ../packages/system-base-packages)
        ];
    };

}
