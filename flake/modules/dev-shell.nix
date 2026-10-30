# `nix develop` in flake/ (or `nix develop ./flake` from the repo root): the
# nix tooling for working on this repo, kept out of the host profiles.
#
# These used to be installed on every host through packages-config/nix-utils/
# (#486). Only what a rebuild or an interactive shell needs stayed there --
# nh (flake/scripts/rebuild.sh calls it), nvd, nix-output-monitor, nix-index.
#
# `just lint` and .githooks/pre-commit re-run themselves inside this shell when
# statix/deadnix aren't on PATH, and CI runs `just preflight` inside it, so the
# lint ratchet always counts with the flake's locked statix/deadnix.
#
# .vscode/settings.json starts nixd as `nix develop ./flake --command nixd`, with
# stdout as the LSP stream -- a shellHook that echoes anything would corrupt it.
# Print from a hook only to stderr (>&2), if one is ever added.
#
# dev-shells/nix/flake.nix is the copy-into-another-project template with the
# same tool list; it is a standalone flake and cannot import this one, so a
# tool added here belongs there too.
#
# This file sits at the top of modules/ rather than in a category directory,
# like checks.nix: it is a flake output, not something a host imports.
{ inputs, ... }: {
    perSystem = { pkgs, inputs', ... }: {
        # `just module-graph` and wiki/config-structure/architecture.md's diagram draw
        # with this (flake/module-graph.toml says where each area goes).
        packages.module-graph = inputs'.flake-module-graph.packages.default;

        devShells.default = pkgs.mkShell {
            packages = with pkgs; [
                just
                python3
                # lint ratchet (`just lint`)
                statix
                deadnix
                # LSPs -- .vscode/settings.json points at nixd
                nixd
                nil
                # formatter; not wired to `nix fmt` on purpose (flake.nix)
                nixfmt
                # closure / derivation inspection
                nix-tree
                nix-diff
                nix-du
                # fetcher calls from repository URLs
                nurl
            ]
            # factcheck (`just wiki-lint`, the edit hook's siblings check).
            # The input's package puts the CLI on PATH so the wrapper
            # (flake/scripts/factcheck.sh) execs it directly; the input's
            # source tree goes with it for the tool's own fixture tests
            # (`just factcheck-test`, flake/scripts/factcheck-test.sh).
            ++ [ inputs'.factcheck.packages.default ];
            env.FACTCHECK_SRC = inputs.factcheck.outPath;
        };
    };
}
