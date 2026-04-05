{
    description = "better pager for some things https://github.com/walles/moor";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            moor # moar renamed to moor https://github.com/walles/moor/pull/305
        ];
    };
}
