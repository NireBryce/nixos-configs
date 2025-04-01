{
    pkgs,
    lib,
    ...
}:

let homeDirectory = /home/elly; # todo: automatee, or at least set only one top level variable
in
{
    environment.systemPackages = with pkgs; [
        pam_u2f
        yubikey-flutter
        yubikey-manager
    ];


    # This is linux only
    services.udev.extraRules = ''
      # # Link/unlink ssh key on yubikey add/remove
      # SUBSYSTEM=="usb", ACTION=="add", ATTR{idVendor}=="1050", RUN+="${lib.getBin yubikey-up}/bin/yubikey-up"
      # # NOTE: Yubikey 4 has a ID_VENDOR_ID on remove, but not Yubikey 5 BIO, whereas both have a HID_NAME.
      # # Yubikey 5 HID_NAME uses "YubiKey" whereas Yubikey 4 uses "Yubikey", so matching on "Yubi" works for both
      # SUBSYSTEM=="hid", ACTION=="remove", ENV{HID_NAME}=="Yubico Yubi*", RUN+="${lib.getBin yubikey-down}/bin/yubikey-down"

      ##
      # Yubikey 4
      ##

      # Lock the device if you remove the yubikey (use udevadm monitor -p to debug)
      # #ENV{ID_MODEL_ID}=="0407", # This doesn't match all the newer keys
      # FIXME(yubikey): We only want this to happen if we're undocked, so we need to see how that works. We probably need to run a
      # script that does smarter checks
      ACTION=="remove",\
       ENV{ID_BUS}=="usb",\
       ENV{ID_VENDOR_ID}=="1050",\
       ENV{ID_VENDOR}=="Yubico",\
       RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"

      ##
      # Yubikey 5 BIO
      #
      # NOTE: The remove event for the bio doesn't include the ID_VENDOR_ID for some reason, but we can use the
      # hid name instead. Some HID_NAME might be "Yubico YubiKey OTP+FIDO+CCID" or "Yubico YubiKey FIDO", etc so just
      # match on "Yubico YubiKey"
      ##

      SUBSYSTEM=="hid",\
       ACTION=="remove",\
       ENV{HID_NAME}=="Yubico YubiKey FIDO",\
       RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"

      # FIXME(yubikey): Change this so it only wakes up the screen to the login screen, xset cmd doesn't work
      # SUBSYSTEM=="hid",\
      #  ACTION=="add",\
      #  ENV{HID_NAME}=="Yubico YubiKey FIDO",\
      #  RUN+="${pkgs.systemd}/bin/loginctl activate 1"
      #  #RUN+="${lib.getBin pkgs.xorg.xset}/bin/xset dpms force on"
    '';


    # Yubikey required services and config. See Dr. Duh NixOS config for
    # reference
    services.pcscd.enable = true; # smartcard service
    services.udev.packages = [ pkgs.yubikey-personalization ];

    # yubikey login / sudo
    security.pam = lib.optionalAttrs pkgs.stdenv.isLinux {
        u2f = {
            enable = true;
            settings = {
                cue         = true; # Tells user they need to press the button
                authFile    = "${homeDirectory}/.config/Yubico/u2f_keys";
            };
        };
        services = {
            login.u2fAuth   = true;
            sudo .u2fAuth   = true;
        };
    };
}
