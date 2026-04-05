{
    homeManager =
    { pkgs, ... }:
    {
        # note: this is also installed as a system package, does that matter?
        home.packages = with pkgs; [ google-chrome ];
        # note: optional pkg
    };
}
