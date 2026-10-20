# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            nix-output-monitor # `nom` nix-output-monitor                  https://github.com/maralorn/nix-output-monitor
        ];
    };
}
