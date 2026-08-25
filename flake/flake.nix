{
    description = "NixOS, nix-darwin and Home Manager configuration for nire's machines";

    outputs = inputs: inputs.flake-parts.lib.mkFlake {
        inherit inputs;
    }
    {
        imports = [
            # declares flake.modules.<class>.<name>, which every module here writes into
            inputs.flake-parts.flakeModules.modules
            # declares flake.darwinConfigurations as lazyAttrsOf raw. Not
            # strictly required -- freeformType on `flake` would accept an
            # undeclared attribute same as nixosConfigurations does -- but it
            # is nix-darwin's own module for exactly this, so there is no
            # reason to skip it.
            inputs.darwin.flakeModules.default
            (inputs.import-tree ./modules)
            # RUNTIME-VERIFIED, 2026-08-25, in CI (.github/workflows/check.yml)
            # on its first real run: without this, `nix flake check` errors
            # outright -- "flake-parts could not determine statically that no
            # formatter is defined for *all* systems" -- because this flake
            # never sets `perSystem.formatter` for either system, and
            # flake-parts' own heuristic for proving that (rather than
            # actually querying perSystem per-system, which it avoids for
            # performance) isn't perfect enough to conclude it on its own.
            # Reproducible locally too on a genuinely fresh clone, full or
            # shallow -- NOT a CI-only issue, just never caught locally
            # because a long-lived dev checkout's own eval had apparently
            # gone stale relative to a truly fresh one, and because piping
            # the check through `tail` (as this session did more than once
            # before CI caught it for real) reads the pipe's own exit code,
            # not the command's. `touchup.attr.formatter.enable = false`
            # drops the `formatter` output entirely rather than defining a
            # trivial one -- consistent with `nix fmt` being deliberately
            # unwired here already (claude-style-guide.md: it would flatten
            # this repo's aligned-`=` columns), so there was never a
            # formatter to expose in the first place.
            inputs.flake-parts.flakeModules.touchup
        ];
        systems = [
            "x86_64-linux"
            "aarch64-darwin"
        ];
        touchup.attr.formatter.enable = false;
    };

    inputs = {
        nixpkgs.url                                = "github:NixOS/nixpkgs/nixos-unstable";
        nixpkgs-lib.follows                        = "nixpkgs";
        
        flake-parts.url                            = "github:hercules-ci/flake-parts";
        flake-parts.inputs.nixpkgs-lib.follows     = "nixpkgs-lib";

        # ── Dendritic toolchain ───────────────────────────────────────────────────
        # systems.url                                = "github:nix-systems/default";
        import-tree.url                            = "github:vic/import-tree";
        # den.url                                    = "github:vic/den";
        # flake-aspects.url                          = "github:vic/flake-aspects";

        # ── Home Manager ──────────────────────────────────────────────────────────
        home-manager.url                           = "github:nix-community/home-manager/master";
        home-manager.inputs.nixpkgs.follows        = "nixpkgs";

        # ── macOS ─────────────────────────────────────────────────────────────────
        darwin.url                                 = "github:LnL7/nix-darwin/master";
        darwin.inputs.nixpkgs.follows               = "nixpkgs";

        # ── Handheld / SteamOS ────────────────────────────────────────────────────
        jovian.url                                 = "github:Jovian-Experiments/Jovian-NixOS";
        jovian.inputs.nixpkgs.follows              = "nixpkgs";

        # ── Impermanence ──────────────────────────────────────────────────────────
        impermanence.url                           = "github:Nix-community/impermanence";

        # Declarative disk partitioning. Not used by any host's own config yet --
        # durandal and tenacity were hand-partitioned, then captured after the
        # fact by nixos-generate-config. Added for
        # nire/impermanence/_disko/impermanence-luks-btrfs.nix, a reusable
        # template for the LUKS+btrfs+impermanence layout those two hosts already
        # use by hand. See flake/doc/disko-impermanence-layout.md.
        disko.url                                  = "github:nix-community/disko";
        disko.inputs.nixpkgs.follows                = "nixpkgs";

        # ── Secrets ───────────────────────────────────────────────────────────────
        sops-nix.url                               = "github:mic92/sops-nix";
        sops-nix.inputs.nixpkgs.follows            = "nixpkgs";

        # ── Nix utilities ─────────────────────────────────────────────────────────
        nixos-hardware.url                         = "github:NixOS/nixos-hardware/master";
        nix-index-database.url                     = "github:nix-community/nix-index-database";
        nix-index-database.inputs.nixpkgs.follows  = "nixpkgs";

    };


}
