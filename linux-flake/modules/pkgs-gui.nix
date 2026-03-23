{ self, inputs, ...}:
{ flake.homeModules.pkgs-gui = {
        imports = [
            (inputs.import-tree ../pkgs-hm/pkgs-gui)
        ];
    };

}
