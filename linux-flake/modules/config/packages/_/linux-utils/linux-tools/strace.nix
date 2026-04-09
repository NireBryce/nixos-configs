{
    description = "system call tracer https://linux.die.net/man/1/strace";

    homeManager = { pkgs, ... }: {
        home.packages = with pkgs; [
            strace
        ];
    };
}
