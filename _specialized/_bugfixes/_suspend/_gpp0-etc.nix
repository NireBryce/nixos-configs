
{ pkgs, ... } :

{
  environment.systemPackages = with pkgs; [ zenstates ];
  # - https://forum.manjaro.org/t/system-do-not-wake-up-after-suspend/76681/2
  # fix-gpp = pkgs.writeScriptBin "_bugfix-suspend-gpp" ''
  #      #!${pkgs.bash}/bin/bash
  #      ${pkgs.sh}/bin/sh -c "echo GPP8 > /proc/acpi/wakeup && echo gpp8 > /proc/acpi/wakeup"  ; # might need to be single caret
  #    '';
  # 
  # 
  #   # from zenstates code comments
  #   before-sleep = pkgs.writeScriptBin "before-sleep" ''
  #      #!${pkgs.bash}/bin/bash
  #      ${pkgs.zenstates}/bin/zenstates --c6-disable
  #   '';
  
  systemd.services.before-sleep = {
      description = "_BUGFIX-suspend (Ryzen disable c6 suspend)";
      wantedBy = [ "sleep.target" "hibernate.target" ];
      before = [ "sleep.target" ];
      serviceConfig.Type = "oneshot";
      # serviceConfig.ExecStart="${before-sleep}";
      serviceConfig.ExecStart="zenstates --c6-disable";
  };

# Gigabyte b550 sleep bug
  # https://www.reddit.com/r/gigabyte/comments/p5ewjn/b550i_pro_ax_f13_bios_sleep_issue_on_linux/
  # 
  # I have a temporary fix for now. You have to disable GPP0 wakeup which is a GPP bridge to the NVMe drive in M.2 slot. Check your wakeup table using cat /proc/acpi/wakeup and look at GPP0. It should say *enabled. Using sudo /bin/sh -c '/bin/echo GPP0 > /proc/acpi/wakeup' you can set it to *disabled. PC should suspend normally then. 
  # systemd.services.fix-suspend-gpp0 = {
  #     description = "_BUGFIX-suspend (GPP0)";
  #     wantedBy = [ "multi-user.target" ];
  #     serviceConfig.Type = "oneshot";
  #     serviceConfig.ExecStart ="echo GPP0 >> /proc/acpi/wakeup";
  # };
  # 
  # https://www.reddit.com/r/archlinux/comments/11urtla/systemctl_suspend_hibernate_and_hybridsleep_all/
  # gpp8 too.  potentially PXTH
  systemd.services.fix-suspend-gpp0-gpp8 = {
      description = "_BUGFIX-suspend (GPP0, GPP8)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart = "${_bugfix-suspend-gpp}";
      serviceConfig.ExecStart = "echo GPP8 > /proc/acpi/wakeup && echo gpp8 > /proc/acpi/wakeup";
  };

}
