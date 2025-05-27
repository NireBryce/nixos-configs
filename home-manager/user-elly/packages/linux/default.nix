{ 
    ... 
}: 
{
  imports = [
    ./gui-pkgs
    ./_lin-sysadmin-pkgs.nix
    ./_steamtinkerlaunch-deps-pkgs.nix
    ./_wayland-pkgs.nix
    ./home-automation.nix
    ./_font-pkgs.nix
  ];
}
