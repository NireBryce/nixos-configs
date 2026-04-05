{
    description = "list open files https://linux.die.net/man/1/lsof";
    
    homeManager =
    { pkgs, ... }:
    {
        home.packages = with pkgs; [
            lsof
        ];
    };
}

