## DO NOT INSTALL THIS BLINDLY, it is NOT a generalist config.  it enables `wipe /root on boot` and `impermanence`.
Poke around the configs, steal what's useful, do NOT install this as a flake no questions asked. I'll fix this later but for now the readme is worthless

I currently use import-tree to import entire folders instead of using a defaults.nix for modularization.

This allows me to move things around without having to edit the paths in the config every time.  But it does make it more confusing.

The flake is the entrypoint, it's a bit of a mess for spectators but it helps keep it easy to maintain.
