{
  ...
}:

{

# Shell integrations go here but main bash config is in the system one.
  # programs.bash.sessionVariables = {
  # };
  # programs.bash.shellAliases = {
  # };
# user bash aliases
  programs.bash.shellAliases = {
    
  };
# Extra commands that should be run when initializing an interactive shell.
  programs.bash.initExtra = ''
  # Add this lines at the top of .bashrc:
    [[ $- == *i* ]] && source $(blesh-share)/ble.sh --noattach
  '';

# Extra commands that should be placed in {file}~/.bashrc.
#   Note that these commands will be run even in non-interactive shells.
  programs.bash.bashrcExtra = ''
    eval "$(is init bash)"
    eval "$(starship init bash)"
    # Add this line at the end of .bashrc:
    [[ ''${BLE_VERSION-} ]] && ble-attach
  '';
# Extra commands that should be run when initializing a login shell.
  programs.bash.profileExtra = ''
  '';
# Extra commands that should be run when logging out of an interactive shell.
  programs.bash.logoutExtra = ''

  '';

  # programs.zellij.enableBashIntegration = true;
  # programs.zoxide.enableBashIntegration = true;
  # programs.starship.enableBashIntegration = true;
  # programs.nix-index.enableBashIntegration = true;
  # programs.kitty.shellIntegration.enableBashIntegration = true;
  # programs.fzf.enableBashIntegration = true;
  # programs.exa.enableBashIntegration = true;
  # programs.atuin.enableBashIntegration = true;
}
