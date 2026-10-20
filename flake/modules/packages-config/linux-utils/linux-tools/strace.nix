# dirs-as-categories: the module is named after this file; its categories are the folders above it
{
    homeManager = { pkgs, ... }: {
        # system call tracer https://linux.die.net/man/1/strace
        home.packages = with pkgs; [
            strace
        ];
    };
}
