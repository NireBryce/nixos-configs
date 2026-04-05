{
    description = "run multiple commands in parallel";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            mprocs
        ];
    };
}
