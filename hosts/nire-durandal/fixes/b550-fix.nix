{
## Temporary B550 suspend fix pending nixos-hardware update
  # TODO: remove this when https://github.com/NixOS/nixos-hardware/pull/1394 goes through
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
    '';
}
