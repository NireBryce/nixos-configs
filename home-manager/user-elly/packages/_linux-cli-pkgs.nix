{
  pkgs,
  ...
}:

{
  # linux only utils (darwin conflicts)
  home.packages = with pkgs; [
    # cli tools
      ethtool                       # ethtool                                   https://www.kernel.org/pub/software/network/ethtool/
      iotop                         # io monitoring                             http://guichaz.free.fr/iotop
      mlocate                       # locate from db built with `updatedb`      https://pagure.io/mlocate
      sysstat                       # system stats                              http://sebastien.godard.pagesperso-orange.fr/
      usbutils                      # lsusb                                     http://www.linux-usb.org/
    # linux debugging
      ltrace                        # library call tracer                       https://linux.die.net/man/1/ltrace
      strace                        # system call tracer                        https://linux.die.net/man/1/strace
    # multi-machine
      input-leap                    # soft-KVM, synergy/barrier fork            https://github.com/input-leap/input-leap
    # system tools              # system tools                              # System Tools
      auto-cpufreq                  # auto-cpufreq                              https://github.com/AdnanHodzic/auto-cpufreq
      lm_sensors                    # lm_sensors                                https://hwmon.wiki.kernel.org/lm_sensors
      libinput                      # TODO: I forget what I need this for.      https://www.freedesktop.org/wiki/Software/libinput/
      xdg-utils                     # xdg-open for stuff like `protontricks`
    
    ## tailscale
      tailscale
      tailscale-systray

    ## Wayland                  # Wayland                                   # Wayland
      wl-clipboard                  # clipboard in wayland                      https://github.com/bugaevc/wl-clipboard
      wl-clipboard-x11              # clipboard in xwayland                     https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=wl-clipboard
      wayland-utils                 # `wayland-info`                            https://gitlab.freedesktop.org/wayland/wayland-utils
      egl-wayland                   # who knows what this is for                https://github.com/NVIDIA/egl-wayland/

    # SteamTinkerLaunch needs these
      xxd
      xdotool
      xorg.xwininfo
      yad
  ];
}
