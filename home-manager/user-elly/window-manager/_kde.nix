{ 
  pkgs,
  lib,
  ... 
}: 
let mouseName = "Logitech Gaming Mouse G600";

in {

  


  # TODO: this requires manual changes if the mouse event ID is different
  # figure out how to variablize it or better yet pull it from libinput via nix
  # https://www.reddit.com/r/linux4noobs/comments/m111ou/changing_middleclick_in_kde_wayland/
  #
  # locate device id (`/dev/input/eventNN`)
  # `sudo libinput list-devices`
  #


  home.activation = { # TODO: every time USB changes, we have to reset this.  Eventually look into ways to automate
                      #   Consider a systemd script or something that runs sudo libinput list-devices and greps for `mouseName` (Bound above) 
    # bugfix-middle-mouse-scroll = lib.hm.dag.entryAfter ["writeBoundary"] ''
    #   /run/current-system/sw/bin/qdbus org.kde.KWin /org/kde/KWin/InputDevice/event5 org.kde.KWin.InputDevice.scrollOnButtonDown true 
    # '';
    # optionally 
    # `qdbus org.kde.KWin /org/kde/KWin/InputDevice/eventNN org.kde.KWin.InputDevice.scrollButton X[`

    #? NOTE: the above causes middle mouse to act as a mouse wheel, so you lose middle click
     
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
