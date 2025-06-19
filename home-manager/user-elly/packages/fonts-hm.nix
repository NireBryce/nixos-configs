{ ... }:
{
    # TODO: duplicated in system fonts, is this for non-nix hosts? consider moving to there
    # description = "font packages that are per-user through home-manager";
    flake.modules.homeManager.base =
    { pkgs, ... }:
    let packageList = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.iosevka
        nerd-fonts.jetbrains-mono
    ];
    
    in
    {
        home.packages = packageList;
    };
}
