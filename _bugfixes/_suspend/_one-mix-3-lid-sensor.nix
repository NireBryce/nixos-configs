{ pkgs, ... } :

{
  systemd.services.one-mix-3-disable-flaky-lid-sensor = {
      enable            = true;
      description       = "disable the broken lid sensor on my machine";
      unitConfig = {
        Type            = "oneshot";
      };
      serviceConfig = {
        User            = "root";                                                        # root may not be necessary
        ExecStart       = "-${pkgs.bash}/bin/bash -c 'if grep 'LID0' /proc/acpi/wakeup | grep -q 'enabled'; then echo 'LID0' > /proc/acpi/wakeup; fi'"; # (1)

        # required to not toggle when `nixos-rebuild switch` is ran
        RemainAfterExit = "yes";                                                         # (2) 
        
      };
      wantedBy = ["multi-user.target"];
    };

}
