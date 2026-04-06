{
    description = "git - git-scm";

    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            git
        ];
    };
}
