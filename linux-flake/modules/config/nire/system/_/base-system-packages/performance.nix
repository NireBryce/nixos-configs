{
    nixos = { pkgs, ... }: {
        environment.systemPackages = with pkgs; [
            auto-cpufreq    # https://github.com/AdnanHodzic/auto-cpufreq
        ];
    };
}
