{ 
    pkgs, 
    ... 
}: 
{
    home.packages = with pkgs;[ 
    # cli tools
        ethtool                       # ethtool                                   https://www.kernel.org/pub/software/network/ethtool/
        iotop                         # io monitoring                             http://guichaz.free.fr/iotop
        mlocate                       # locate from db built with `updatedb`      https://pagure.io/mlocate
        sysstat                       # system stats                              http://sebastien.godard.pagesperso-orange.fr/
        usbutils                      # lsusb                                     http://www.linux-usb.org/
    # linux debugging
        ltrace                        # library call tracer                       https://linux.die.net/man/1/ltrace
        strace                        # system call tracer                        https://linux.die.net/man/1/strace
        
    # system tools              # system tools                              # System Tools
        #todo: move to system cfg
        auto-cpufreq                  # auto-cpufreq                              https://github.com/AdnanHodzic/auto-cpufreq
        lm_sensors                    # lm_sensors                                https://hwmon.wiki.kernel.org/lm_sensors
        libinput                      # kde middle mouse scroll fix requires this
        xdg-utils                     # xdg-open for stuff like `protontricks`
    
    ];
}
