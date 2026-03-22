{ self, inputs, ...}:
{ flake.homeModules.pkgs-cli = {
        imports = [
            (inputs.import-tree ./pkgs-cli)
        ];
    };

}
