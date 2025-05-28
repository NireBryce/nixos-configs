{ 
    pkgs, 
    ... 
}: 
{
    # todo: move to linux specific
    home.packages = with pkgs;[ 
        lsof                          # list open files                           https://linux.die.net/man/1/lsof
        pciutils                      # lspci                                     https://mj.ucw.cz/sw/pciutils/
    ];
}

