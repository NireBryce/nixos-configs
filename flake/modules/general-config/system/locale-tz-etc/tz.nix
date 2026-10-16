# Module file: named after this file; why it looks this way: wiki/module-files.md
{ lib, ... }:
{
    nixos = {
        time.timeZone = lib.mkDefault "America/New_York";
    };
}
