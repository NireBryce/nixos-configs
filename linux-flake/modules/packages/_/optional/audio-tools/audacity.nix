{
    homeManager =
    { pkgs, ... }:
    {
    home.packages = with pkgs; [
            audacity
        ];
    };
    # note: optional pkg
}
