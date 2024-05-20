{pkgs, ...}:
# user packages are managed by fleek (a home-manager frontend) and are in a
# different repo
{
  # List packages installed in system profile. To search, run:
  # $ nix search <package name>
  environment.systemPackages = with pkgs; [
    bash
    coreutils
    curl
    gcc
    git
    micro # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    stdenv
    wget
    zoxide
    rg
    nix-output-monitor # https://github.com/maralorn/nix-output-monitor
    nh # https://github.com/viperML/nh
    linuxHeaders
  ];
  services.fwupd.enable = true;

  programs.nix-ld.enable = true; # Needed for VSCode remote connection

  programs.kdeconnect.enable = true;

  # https://github.com/viperML/nh
  programs.nh = {
    enable = true;
    # clean.enable = true;
    # clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/elly/nixos";
  };

  # shells
  environment.shells = with pkgs; [
    bash
    zsh
  ];
}
