{ self, inputs, ...}:
{ 
flake.homeModules.elly ={
    imports = with self.homeModules; [ 
        virtualization
        elly-aliases
        elly-fonts
        elly-git
        elly-hm-settings
        elly-home-config
        elly-nix-settings
        elly-shell-bash
        elly-shell-fish
        elly-shell-zsh
        pkgs-linux-utils
        pkgs-gui
        pkgs-cli
    ];
};
}
