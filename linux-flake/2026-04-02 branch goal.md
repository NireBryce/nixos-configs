the goal here is to merge the home manager and nixos options (and eventually darwin) into the same modules


see https://dendrix.oeiuwq.com/Dendritic.html

ex
```nix
# modules/ssh.nix -- like every other file inside modules, this is a flake-parts module.
{ inputs, config, ... }: let
  scpPort = 2277; # let-bindings or custom flake-parts options communicate values across classes
in {
  flake.modules.nixos.ssh = {
    # Linux config: setup OpenSSH server, firewall-ports, etc.
  };

  flake.modules.darwin.ssh = {
    # MacOS config: enable MacOS builtin ssh server, etc.
  };

  flake.modules.homeManager.ssh = {
    # setup ~/.ssh/config, authorized_keys, private keys secrets, etc.
  };

  perSystem = {pkgs, ...}: {
    # custom packages taking advantage of ssh facilities, eg deployment-scripts.
  };
}

```




2026 04 04 
need to go through and mark optional/required packages and weed optionals I dont use


2026 04 06 
i've got most of it working but it keeps hanging on being unable to find nixosConfigurations, consider falling back to the intermediary example flake tomorrow

2026-04-08 

I think that .provides.all doesn't work because it risks multiple include but i haven't experimented yet 
