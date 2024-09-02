{ 
  pkgs,
  lib,
  ... 
}: 
let mouseName = "Logitech Gaming Mouse G600";

in {

  
  # check for KDE, install KDE packages
  # TODO: figure out what to do with this, they really belong in packages.  Is there a way to make nix disable packages if one isn't installed?
  # look into if you can do mkifs based on system.windowManager.etc or whatever it is

    home.packages = with pkgs; [    # kde utilities just in case they aren't in nixOS' metapackage
      kdePackages.qttools
      partition-manager
      kcharselect        # symbol picker, may need to be kdePackages.kcharselect
    ];

  # TODO: this requires manual changes if the mouse event ID is different
  # figure out how to variablize it or better yet pull it from libinput via nix


  # https://www.reddit.com/r/linux4noobs/comments/m111ou/changing_middleclick_in_kde_wayland/
  #
  # locate device id (`/dev/input/eventNN`)
  # `sudo libinput list-devices`
  #


  home.activation = { # TODO: every time USB changes, we have to reset this.  Eventually look into ways to automate
                      #   Consider a systemd script or something that runs sudo libinput list-devices and greps for `mouseName` (Bound above) 
    bugfix-middle-mouse-scroll = lib.hm.dag.entryAfter ["writeBoundary"] ''
      /run/current-system/sw/bin/qdbus org.kde.KWin /org/kde/KWin/InputDevice/event5 org.kde.KWin.InputDevice.scrollOnButtonDown true 
    '';
    # optionally 
    # `qdbus org.kde.KWin /org/kde/KWin/InputDevice/eventNN org.kde.KWin.InputDevice.scrollButton X[`
  };

  # potential automation of it:
  # systemd.services.kwin-mouse = {
  #   wantedBy = [ "Multi-user.target" ];
  #   enable = true;
  #   serviceConfig = {
  #     User = "root";
  #     Group = "root";
  #     ExecStart = '' 
  #       /run/current-system/sw/bin/qdbus org.kde.KWin /org/kde/KWin/InputDevice/''$(${pkgs.libinput}/bin/libinput list-devices | rg "Logitech Gaming Mouse G600" --after-context 1  --max-count=1 | rg "event." --only-matching) org.kde.KWin.InputDevice.scrollOnButtonDown true
  #     '';
  #   };
  # };

}
