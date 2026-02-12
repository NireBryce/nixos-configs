{
    ...
}:
{ den.aspects.nixos.provides.secrets = 
{ pkgs, lib, config, ... }: 
let homeDirectory = "${config.users.users.elly.home}";  # todo: automatee, or at least set only one top level variable
in
{
    environment.systemPackages = with pkgs; [
        pam_u2f
        yubioath-flutter
        yubikey-manager
    ];


    # This is linux only
    services.udev.extraRules = ''
    
    # Yubikey 4 / bio need different config
    #   ##
    # Yubikey 5 BIO
    #
    # NOTE: The remove event for the bio doesn't include the ID_VENDOR_ID for some reason, but we can use the
    # hid name instead. Some HID_NAME might be "Yubico YubiKey OTP+FIDO+CCID" or "Yubico YubiKey FIDO", etc so just
    # match on "Yubico YubiKey"
    ##

        SUBSYSTEM=="hid",\
        ACTION=="remove",\
        ENV{HID_NAME}=="Yubico YubiKey FIDO+CCID",\
        RUN+="${pkgs.systemd}/bin/loginctl lock-sessions"

        # FIXME(yubikey): Change this so it only wakes up th    e screen to the login screen, xset cmd doesn't work
        SUBSYSTEM=="hid",\
        ACTION=="add",\
        ENV{HID_NAME}=="Yubico YubiKey FIDO+CCID",\
        RUN+="${pkgs.systemd}/bin/loginctl activate 1"
        
    '';


    # Yubikey required services and config. See Dr. Duh NixOS config for
    # reference
    services.pcscd.enable  = true; # smartcard service
    services.udev.packages = [ pkgs.yubikey-personalization ];

    # yubikey login / sudo
    security.pam = lib.optionalAttrs pkgs.stdenv.isLinux {
        u2f = {
            enable      = true;
            settings    = {
                cue         = true; # Tells user they need to press the button
                authFile    = "${homeDirectory}/.config/Yubico/u2f_keys";
            };
        };
        services    = {
            login.u2fAuth   = true;
            sudo .u2fAuth   = true;
        };
    };
}
;}
