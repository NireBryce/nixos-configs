# copied from https://guekka.github.io/nixos-server-2/ almost verbatim
# many of the comments are straight from the post
 
{ 
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # (1)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"; # (1)
    impermanence.url = "github:Nix-community/impermanence";
  # secret management
    sops-nix = { 
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      # What\'s up with this follows? sops-nix already depends on nixpkgs, 
      # but it might use a different revision than ours. Making it use our 
      # own has several advantages:
      # - improve consistency
      # - reduce number of evaluations needed
      # 
      # And how do we know if a package has inputs that need to be redirected? 
      # That\'s the neat thing, we don\'t. Either we have to look at the upstream 
      # flake.nix, or we can call nix flake info and get a graph
    };
  };


  # { nixpkgs, ... }@inputs: nixpkgs
  #
  # is the same as:
  #
  # inputs: inputs.nixpkgs

  outputs = { nixpkgs, ... }@inputs: {
    nixosModules = import ./modules/nixos;

    nixosConfigurations."nire-durandal" = nixpkgs.lib.nixosSystem {
      # packages = nixpkgs.legacyPackages.x86_64-linux;
      specialArgs = inputs;
      modules = [
        ./nire-durandal
        # shared modules
          ./_common  # I try to keep non-CLI things out of this, so it can still be deployed to servers
          ./_specialized
          ./_specialized/_gpu/_amdgpu.nix
          ./_specialized/_mouse/_logitech_gaming.nix
        # fixes
          ./_bugfixes/_suspend/_b550m-gpp0-etc.nix
      ];
    };

    nixosConfigurations."nire-lysithea" = nixpkgs.lib.nixosSystem { # (3)
      # packages = nixpkgs.legacyPackages.x86_64-linux;
      specialArgs = inputs; # forward inputs to modules
      modules = [
        ./nire-lysithea

      ];
    };
    nixosConfigurations."nire-galatea" = nixpkgs.lib.nixosSystem { # (3)
      # packages = nixpkgs.legacyPackages.x86_64-linux;
      specialArgs = inputs; # forward inputs to modules
      modules = [
        ./nire-galatea
      ];
    };
  };
}
################################################################################
# NOTE FOR ZSH
# https://www.reddit.com/r/NixOS/comments/1539s44/using_flakes_for_configurationnix/
# https://stackoverflow.com/questions/12303805/oh-my-zsh-hash-pound-symbol-bad-pattern-or-match-not-found/57380936#57380936
# this fixes nix-flakes
#   disable -p '#'
# otherwise `nixos-rebuild --flake .#hostname` will not get evaluated correctly.
################################################################################

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
   * In flakes this behavior is 'modules'
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

