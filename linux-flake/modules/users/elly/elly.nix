{ self, inputs, ...}:
{ 
flake.modules.homeManager.ellyHomeManager ={
    # TODO: this needs to exclude every host for now, which is not a workable solution!
    # list `[ ]` of all modules under 'self.modules.nixos.*'
    imports = builtins.attrValues (builtins.removeAttrs self.modules.homeManager [ "ellyHomeManager" ]);
};
}

    # imports = [ 
    #     self.modules.homeManager.virtualization
    #     self.modules.homeManager.elly-aliases
    #     self.modules.homeManager.elly-fonts
    #     self.modules.homeManager.elly-git
    #     self.modules.homeManager.elly-hm-settings
    #     self.modules.homeManager.elly-home-config
    #     self.modules.homeManager.elly-nix-settings
    #     self.modules.homeManager.elly-shell-bash
    #     self.modules.homeManager.elly-shell-fish
    #     self.modules.homeManager.elly-shell-zsh
    #     self.modules.homeManager.pkgs-linux-utils
    #     self.modules.homeManager.pkgs-gui
    #     self.modules.homeManager.pkgs-cli
    #     self.modules.homeManager.nix-index
    # ];
