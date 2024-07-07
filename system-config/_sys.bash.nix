{ 
  pkgs,
  ... 
}:
{
  environment.systemPackages = with pkgs; [
    inshellisense
    starship
    blesh
  ];
  programs.bash.interactiveShellInit = ''
  # Add this lines at the top of .bashrc:
      [[ $- == *i* ]] && source ''$(blesh-share)/ble.sh --noattach
    
    eval "$(is init bash)"
    
  '';
  programs.bash.promptInit = ''
    eval "$(starship init bash)"
    # Add this line at the end of .bashrc:
    [[ ''${BLE_VERSION-} ]] && ble-attach
  '';
  programs.bash.enableCompletion = false;
  
  
}
