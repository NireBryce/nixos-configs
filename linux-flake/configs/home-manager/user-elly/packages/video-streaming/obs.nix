{ pkgs, ... }:
{
    programs.obs-studio = {
        enable = true;                  # screen recording / streaming         https://obsproject.com/
        plugins = with pkgs; [ 
            obs-studio-plugins.obs-vaapi  # enables AMD hardware accel?
        ];
    };
}
