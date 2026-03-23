{ self, inputs, ...}:
{ flake.homeModules.pkgs-cli = {
        imports = [
            (inputs.import-tree ../packages/pkgs-hm/pkgs-cli)
        ];
    };

}
