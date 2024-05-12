# Fleek Configuration

nix home-manager configs created by [fleek](https://github.com/ublue-os/fleek).

## Reference

- [home-manager](https://nix-community.github.io/home-manager/)
- [home-manager options](https://nix-community.github.io/home-manager/options.html)

## Usage

Aliases were added to the config to make it easier to use. To use them, run the following commands:

```bash
# To change into the fleek generated home-manager directory
$ fleeks
# To apply the configuration
$ apply-$(hostname)
```

Your actual aliases are listed below:
    apply-nire-durandal = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-durandal";

    apply-nire-galatea = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-galatea";

    apply-nire-lysithea = "nix run --impure home-manager/master -- -b bak switch --flake .#elly@nire-lysithea";

    fleek-custom = "micro ~/.local/share/fleek/nire-lysithea/custom.nix";

    fleek-edit = "micro ~/.fleek.yml";

    fleek-user = "micro ~/.local/share/fleek/user.nix";

    fleeks = "cd ~/.local/share/fleek";

    latest-fleek-version = "nix run https://getfleek.dev/latest.tar.gz -- version";

    update-fleek = "nix run https://getfleek.dev/latest.tar.gz -- update";
