{
    pkgs,
    ...
}:
{
    environment.systemPackages = with pkgs; [
        nix-output-monitor          # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
        nh                          # nix helper                                https://github.com/viperML/nh
    ];

    programs.nh = {
        enable          = true;
        clean.enable    = true;
        clean.extraArgs = "--keep-since 7d --keep 5";
        flake           = "/home/elly/nixos"; # TODO: see if this can be dynamically set to this flake's path
    };


}
