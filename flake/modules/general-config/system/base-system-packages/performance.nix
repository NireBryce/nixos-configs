# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            auto-cpufreq # https://github.com/AdnanHodzic/auto-cpufreq
        ];
    };
}
