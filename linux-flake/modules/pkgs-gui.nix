{ self, inputs, ...}:
{ flake.modules.homeManager.pkgs-gui = {
        imports = [
            (inputs.import-tree ../pkgs-hm/pkgs-gui)
        ];
    };

}
