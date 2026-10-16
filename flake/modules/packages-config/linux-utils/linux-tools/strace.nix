# Module file: named after this file; why it looks this way: wiki/module-files.md
{
    homeManager = { pkgs, ... }: {
        # system call tracer https://linux.die.net/man/1/strace
        home.packages = with pkgs; [
            strace
        ];
    };
}
