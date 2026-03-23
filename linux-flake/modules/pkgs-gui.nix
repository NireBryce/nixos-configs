{ self, inputs, ...}:
{ flake.homeModules.pkgs-gui = {
        imports = [
            (inputs.import-tree ../packages/pkgs-hm/pkgs-gui)
        ];
    };

}
