{
    description = "library call tracer https://linux.die.net/man/1/ltrace";
    
    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            ltrace
        ];
    };
}
