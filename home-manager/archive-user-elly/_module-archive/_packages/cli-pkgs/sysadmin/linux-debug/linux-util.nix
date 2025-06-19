{ 
    pkgs, 
    ... 
}: 
{
    # todo: system config?
    home.packages = with pkgs;[ 
        lsof                          # list open files                           https://linux.die.net/man/1/lsof
        pciutils                      # lspci                                     https://mj.ucw.cz/sw/pciutils/
        ltrace                        # library call tracer                       https://linux.die.net/man/1/ltrace
        strace                        # system call tracer                        https://linux.die.net/man/1/strace
        sysstat                       # system stats                              http://sebastien.godard.pagesperso-orange.fr/
        iotop                         # io monitoring                             http://guichaz.free.fr/iotop
        usbutils                      # lsusb                                     http://www.linux-usb.org/
    ];
}

