{ lib, ... }:
    let
        moduleName = lib.removeSuffix ".nix" (baseNameOf __curPos.file);
    in {
        # A bare attrset, not `{ ... }: { ... }`: this body references no
        # module arguments, an empty pattern is a statix finding
        # (`scripts/lint-baseline.json`, enforced by `.githooks/pre-commit`),
        # and skipping the lambda also skips the two-`config`s shadowing trap
        # skill `new-flake-module` describes.
        flake.modules.nixos.${moduleName} = {
            # # description = "Render the Forgejo API token to /run/secrets, readable by elly"

            # A CLIENT credential, unlike every other secret in this tree: it
            # authenticates the USER (or an agent acting for them) against the
            # forge's REST API from whatever host they're sitting at --
            # creating a repo, adding a mirror, `fj auth add-token`. Nothing on
            # the server side reads it; forgejo.nix's own
            # `forgejo-admin-password` is the cube-only, service-side one.
            #
            # Declared in the `system` category, so it renders on ALL THREE
            # Linux hosts -- deliberately NOT following the "declare it where
            # it's used" rule sops.nix's history note and forgejo.nix's header
            # both state. That rule exists to keep a SERVICE's secret off hosts
            # not running the service; the "host that uses" a client token is
            # whichever one the user happens to be working from, which is
            # durandal and tenacity today and could be either tomorrow.
            # Declaring it per-host would mean the same four lines twice, going
            # stale separately. Cube gets it too as a side effect -- accepted:
            # cube is enrolled in `.sops.yaml` like every other host and can
            # already decrypt the whole file, so this changes what is RENDERED
            # at activation, not who could read it in principle.
            #
            # `owner = "elly"` is the whole point of the module: at the default
            # root:root 0400 the user would need `sudo` to read it, and an
            # interactive `sops -d --extract` (the thing this replaces, per
            # skill `secrets-hygiene`) would still be the path of least
            # resistance. `elly` is hardcoded here for the same reason it is in
            # `users.users.elly` and `home-manager.users.elly` -- CLAUDE.md's
            # Conventions; there is no `nire.primaryUser` option in this tree.
            #
            # Key name is `forgejo_api_key` with UNDERSCORES, matching
            # secrets.yaml's own key (`just read-sops-names`) -- sops-nix
            # derives `sops.secrets.<name>.key` from the attribute name, so a
            # hyphenated spelling here would decrypt nothing and fail at
            # activation, not at eval.
            #
            # sopsFile unset: defaults to `config.sops.defaultSopsFile`, set to
            # secrets.yaml by sops.nix in this same directory.
            sops.secrets.forgejo_api_key = {
                owner = "elly";
                mode  = "0400";
            };
        };
}
