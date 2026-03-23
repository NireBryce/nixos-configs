{ self, inputs, ...}:
{ flake.modules.nixos.nix = { 
    # TODO: find a better way to merge these
    imports = [
        self.modules.nixos.nix-settings 
        self.modules.nixos.nix-utils
    ];
};

}

