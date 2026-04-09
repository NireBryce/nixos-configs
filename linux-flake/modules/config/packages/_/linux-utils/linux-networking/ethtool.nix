{
    description = "ethtool https://www.kernel.org/pub/software/network/ethtool/";
    
    homeManager =  { pkgs, ... }: {
        home.packages = with pkgs; [
            ethtool
        ];
    };
}
