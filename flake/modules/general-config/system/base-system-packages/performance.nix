# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            auto-cpufreq # https://github.com/AdnanHodzic/auto-cpufreq
        ];
    };
}
