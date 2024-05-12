{ pkgs, ... }: {
  home.packages = [
    # TODO: lib.mkIf lib.mkEnable games
    pkgs.teamspeak_client # ts3
  ];
}
