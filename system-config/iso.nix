# originally https://github.com/EmergentMind/nix-config/blob/f8aad6648cf6e881ab09d16a400af973cb235b4e/hosts/nixos/iso/default.nix

#NOTE: This ISO is NOT minimal. We don't want a minimal environment when using the iso for recovery purposes.
{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

let
    _hostname = "nire-bootstrap";
    _username = "elly";
    _subconfigList = [
        ../z-create-iso
    ];      

in
{
    networking.hostName = _hostname;
    
    imports = lib.flatten [
        "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
        _subconfigList
    ];

    #TODO: git creds

    environment.etc = {
        isoBuildTime = {
            # builtins.currentTime requires --impure
            text = lib.readFile (''${pkgs.runCommand 
                "timestamp" { env.when = builtins.currentTime; } 
                "echo -n `date -d @$when  +%Y-%m-%d_%H-%M-%S` > $out"
            }'');
        };
    };

  # Add the build time to the prompt so it's easier to know the ISO age
  programs.bash.promptInit = ''
    export PS1="\\[\\033[01;32m\\]\\u@\\h-$(cat /etc/isoBuildTime)\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ "
  '';

  # The default compression-level is (6) and takes too long on some machines (>30m). 3 takes <2m
  isoImage.squashfsCompression = "zstd -Xcompression-level 3";

  # todo: submodule iso nix settings
  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    config.allowUnfree = true;
  };
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    extraOptions = "experimental-features = nix-command flakes";
  };

  # todo: ssh?
  
  # todo: submodule iso boot settinga


}
