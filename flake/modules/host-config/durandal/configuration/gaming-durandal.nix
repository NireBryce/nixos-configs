# dirs-as-categories: the module is named after this file; its categories are the folders above it
# Heroic and GameMode on durandal (Ryzen 7 5800X, RX 6700 XT / Navi 22,
# 32 GB), added for Alan Wake 2, an Epic Games Store title. The shared
# gaming.nix (Steam, MangoHud, protonup-qt) already reaches this host
# through `system`; this sits beside it rather than in it so tenacity, which
# runs Jovian's own session, isn't changed along with it.
#
# Already in place, not repeated here: AW2 requires mesh shaders, which RADV
# exposes on RDNA2 (Mesa 26.2.5 in the tree as of 2026-10-22);
# programs.gamescope.enable comes from steam's gamescopeSession; and
# vm.max_map_count is already 1048576 by nixpkgs default.
{
    nixos = { pkgs, ... }: {
        # # description = "durandal: Heroic Games Launcher with GameMode and gamescope";

        # Heroic runs games inside its own FHS wrapper, which leaves out
        # gamemode and gamescope (https://wiki.nixos.org/wiki/Heroic_Games_Launcher),
        # so its per-game toggles find nothing unless they're added here.
        # GE-Proton/Wine builds come from Heroic's own Wine Manager.
        environment.systemPackages = with pkgs; [
            (heroic.override {
                extraPkgs = pkgs': with pkgs'; [
                    gamescope
                    gamemode
                ];
            })
        ];

        # gamemoded raises game priority and switches the CPU governor to
        # performance while a game holds it. The polkit rules gamemode ships
        # let only members of the `gamemode` group change the governor
        # without a password prompt.
        programs.gamemode = {
            enable   = true;
            settings = {
                general.renice = 10;
            };
        };
        users.users.elly.extraGroups = [ "gamemode" ];
    };
}
