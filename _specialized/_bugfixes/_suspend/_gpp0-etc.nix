{ pkgs, lib, ... } :

{
  systemd.services.bugfixSuspend-GPP0 = {
      enable            = true;
      description       = "Fix lack of wakeup on suspend/hibernate [...]/_bugfixes/_suspend/_gpp0-etc.nix)";
      unitConfig = {
        Type            = "oneshot";
      };
      serviceConfig = {
        User            = "root";                                                        # root may not be necessary
        ExecStart       = "-${pkgs.bash}/bin/bash -c 'if grep 'GPP0' /proc/acpi/wakeup | grep -q 'enabled'; then echo 'GPP0' > /proc/acpi/wakeup; fi'"; # (1)

        # required to not toggle when `nixos-rebuild switch` is ran
        RemainAfterExit = "yes";                                                         # (2) 
        
      };
      wantedBy = ["multi-user.target"];
    };

  systemd.services.bugfixSuspend-GPP8 = {
      enable            = true;
      description       = "Fix immediate wakeup on suspend/hibernate [...]/_bugfixes/_suspend/_gpp0-etc.nix)";
      unitConfig = {
        Type            = "oneshot";
      };
      serviceConfig = {
        User            = "root";
        ExecStart       = "-${pkgs.bash}/bin/bash -c 'if grep 'GPP8' /proc/acpi/wakeup | grep -q 'enabled'; then echo 'GPP8' > /proc/acpi/wakeup; fi'"; # (1)
        RemainAfterExit = "yes";                                                         # (2)
      };
      wantedBy = ["multi-user.target"];
    };

  # Potentially unnecessary but enabling anyway for now
  environment.systemPackages = with pkgs; [ zenstates ]; 
  systemd.services.bugfixSuspend-c6-disable = {
      description = "Ryzen disable c6 suspend ([...]/_bugfixes/_suspend/_gpp0-etc.nix)";
      wantedBy = [ "sleep.target" "hibernate.target" ];
      before = [ "sleep.target" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart="zenstates --c6-disable";
  };



}

# Shoutouts:
# (1) thanks to this systemd service example from u/dustythermals https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/hb32elw/
# (2) thanks to help from https://github.com/ToxicFrog
# Huge credit to /u/theHugePotato who found the root cause https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/h9plj88/ 

# Breadcrumbs:
# https://www.reddit.com/r/gigabyte/comments/p5ewjn/b550i_pro_ax_f13_bios_sleep_issue_on_linux/
# https://www.reddit.com/r/archlinux/comments/11urtla/systemctl_suspend_hibernate_and_hybridsleep_all/
# https://forum.manjaro.org/t/system-do-not-wake-up-after-suspend/76681/2

# This affects at least:
# - Gigabyte b550m-d3sh (my machine)
# - Gigabyte B550i AORUS Pro Ax https://www.reddit.com/r/gigabyte/comments/p5ewjn/b550i_pro_ax_f13_bios_sleep_issue_on_linux/
# - Gigabyte B550 Vision D https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/hb32elw/
# - Gigabyte B550 Aorus Pro https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/ijsx8ia/
# - Gigabyte B550 Aorus Pro AC https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/j6cbnwq/
# - Gigabyte B550 Aorus Pro v2 https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/imx7sz0/
#    - B550 Aorus Pro may need GPP0 and PTXH instead of GPP8, I don't have hardware to test
# - Gigabyte B550 Aurus Elite v2 https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/k2psbgu/
# - Gigabyte B550m pro https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/huocd81/
# - Gigabyte B550m Aorus Elite https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/hzngaa7/
# - Gigabyte B550 Gaming X v2 https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/hvojl44/
# - Gigabyte B550 Aorus Master v1.0 https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/j1alpxk/

#
# Anecdotes of other boards:
# - Gigabyte A520M https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/i57jpjw/









# monument to removed lines that may be useful
  # # modification from https://www.reddit.com/r/gigabyte/comments/p5ewjn/comment/ksbm0mb/ /u/Demotay
  # ExecStart = "-${pkgs.bash}/bin/bash -c 'if grep 'GPP8' /proc/acpi/wakeup | grep -q 'enabled'; then echo 'GPP8' > /proc/acpi/wakeup; fi'";

  # ExecStart = "-${pkgs.bash}/bin/bash -c 'if grep 'GPP0' /proc/acpi/wakeup | grep -q 'enabled'; then echo 'GPP0' > /proc/acpi/wakeup; fi'";
  


