{ 
    ... 
}: 
{
  imports = [
    ./_dev-pkgs.nix
    ./_general-cli-pkgs.nix
    ./_nix-util-pkgs.nix
    ./_shell-util
    ./_sysadmin-pkgs.nix
    ./editors
    ./file-transfer
    ./help-systems

    ./topgrade
    ./zoxide
    ./nix-index
    ./fzf
    ./eza
    ./direnv
    ./dircolors
    ./broot
    ./atuin
  ];
}
