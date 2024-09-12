{
  ...
}:

{


  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication       = false;
    KbdInteractiveAuthentication = false;
    X11Forwarding                = false;
  };
  services.openssh.extraConfig = ''
      AllowTcpForwarding yes
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AuthenticationMethods publickey
    '';
}
