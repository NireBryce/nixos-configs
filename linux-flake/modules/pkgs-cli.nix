{ self, inputs, ...}:
{ flake.modules.homeManager.pkgs-cli = {
        imports = [
            (inputs.import-tree ../pkgs-hm/pkgs-cli)
        ];
    };

}
