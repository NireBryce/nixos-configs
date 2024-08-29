{ 
  pkgs,
  lib,
  ... 
}: 

{

  
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

  home.activation = { 
    bugfix-middle-mouse-scroll = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ''$HOME/.nix-profile/bin/qdbus org.kde.KWin /org/kde/KWin/InputDevice/event4 org.kde.KWin.InputDevice.scrollOnButtonDown true 
    '';
    # optionally 
    # `qdbus org.kde.KWin /org/kde/KWin/InputDevice/eventNN org.kde.KWin.InputDevice.scrollButton X[`
  };

}
