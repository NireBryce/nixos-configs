{ config, pkgs, ... }:

let
  impermanence = builtins.fetchTarball "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in
{ 
  # hostname
    networking.hostName = "nire-durandal"; 
  
  imports = [ 

    # nix generated
      ./hardware-configuration.nix
      ./durandal.stateVersion.nix
    
    # machine-specific
      ./_durandal-users.nix
    
    # shared modules
      ../_common  # I try to keep non-CLI things out of this, so it can still be deployed to servers
      ../_specialized/_bluetooth
      ../_specialized/_gpu/_amdgpu.nix
      ../_specialized/_gui
      ../_specialized/_mouse
      ../_specialized/_sound

    # fixes
      ../_bugfixes/_suspend/_b550m-gpp0-etc.nix

  ];
  



}

  /* Let's try something: I found a lot of my nix configs from other people, but
   * had to scour for their blogs.  Let's just do this:
   *
   * At it's heart I think the power of nixos is easier to understand if you 
   * think of these as straight up config files from any other shell rc or 
   * vim config or whatever.
   * 
   * If you play around with them like config files, pulling bits and pieces from
   * everyone's github, and look up syntax etc as you need, you will, imo, have 
   * a much easier time learning and grokking the deeper parts of nix.
   * 
   * (hint: github code search configuration.nix, flake.nix, or 
   * home.nix depending on what you're looking for).
   * 
   * For now, if it helps, you can ignore the parts where nix describes itself 
   * as a functional language.  
   * 
   * Instead:
   * ```
   *    { ... }:
   *    {
   *      ...
   *    }
   * ```
   * can largely be thought of as boilerplate for now.  importantly, 
   * the `...` in { ... } at the top, is an actual part of the file.
   * 
   * You will often see { pkgs, ... }: and { pkgs, cfg, ... }: depending on
   * what you're doing.  At first, you can sort of just put those in whenever it
   * doesn't work with just { ... }:
   * 
   * This is bad practice, but we're trying to get you up to speed, not to write
   * perfect nix.  By the time you will be primed for understanding the descriptions,
   * you'll already be looking for what it means.
   * 
   * Let's face it, you're trying to install NixOS on your daily driver, probably,
   * if you're here.  You'll learn faster once you have more experience playing, 
   * imho.
   * 
   * ```
   * imports = [
   *   ./<some-path-here>
   * ];
   * ```
   * can be seen as equivalent to `source <some-path-here>` in .bashrc or .zshrc
   *
   * if the line ends in .nix, it loads that module directly.
   * 
   * if the line is just the name of a folder, it loads 
   * `<path>/default.nix`, as you see in the file you're currently in.
   * 
   * You can ignore everything here but _durandal-users.nix (the computer that,
   * at writing, has an up to date config unlike the rest)
   *  
   * and ./_common
   * 
   * The next step would be ._/common/default.nix
   * 
   * I probably won't write more in these for awhile, but hopefully that gets you started
   * 
   * for flakes, you don't need configuration.nix, as you can see.  it's just a convention.
   * 
   * If you're lost and don't know what called this, look at `../flake.nix`, as that's the entrypoint.
   */



