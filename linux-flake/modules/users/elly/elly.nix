{ self, inputs, ...}:
{ 
flake.modules.homeManager.elly ={
    imports = [ 
        self.modules.homeManager.virtualization
        self.modules.homeManager.elly-aliases
        self.modules.homeManager.elly-fonts
        self.modules.homeManager.elly-git
        self.modules.homeManager.elly-hm-settings
        self.modules.homeManager.elly-home-config
        self.modules.homeManager.elly-nix-settings
        self.modules.homeManager.elly-shell-bash
        self.modules.homeManager.elly-shell-fish
        self.modules.homeManager.elly-shell-zsh
        self.modules.homeManager.pkgs-linux-utils
        self.modules.homeManager.pkgs-gui
        self.modules.homeManager.pkgs-cli
    ];
};
}
