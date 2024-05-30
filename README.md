## DO NOT INSTALL THIS BLINDLY, it is NOT a generalist config.  it enables `wipe /root on boot` and `impermanence`.
Poke around the configs, steal what's useful, do NOT install this as a flake no questions asked.

## Glossary:
### Underscore Prefixes
Because I want to categorize things with common abbreviations nixOS and other 
common modules use, I put an underscore in front of prefixes just in case.
### General lack of `default.nix`
VSCode and other editors just display 'default.nix' in the editor tabs. 
I know it makes for more typing, but overall the increase to navigational
efficiency helps me maintain it, and this is my dotfiles.  Until LSP tooling
gets better I'm not changing it.  If you have ideas, I'm 100% willing to 
hear them.
### Folders
- `./0H*-<hostname>` - directory containing host files.  Right now nire-durandal is the only one that works, I'm in the middle of refactoring the rest but I don't boot them right now.
    - example: `./0H1-nire-durandal/
- `./0U*-<username>/home-manager` - directory containing user descriptions and user + machine specific home-manager files.
    - When they're host specific, they're written `./OU*-elly/0U*h*-<hostname>.nix`
        - `./0U*-<username>/_0U1h1-nire-durandal.nix` 
    - 
- 
### Prefixes:
``` 
# Files
   __def    - default.nix-style meta-modules
    _hm     - home-manager configs
    _sys    - system and admin
    _pkg    - installed packages
    _sec    - security
    _nix    - nix settings
    _wm     - window-manager specifc config
    _zsh    - zsh-specific config
# Folders
    _bugfixes   - specific bugfixes
    _dev        - development stuff (WIP)
    _dotfiles   - where dotfiles are stored, to be linked via home-manager
    modules     - modules you wish were upstream
    services    - stuff like tailscale, etc that doesn't need much tinkering
    
```
Map:
- System modules are managed via 
- User packages are managed via Home-Manager, in `./0UX-<user>/<user>-home-manager/hm.<user>.pkgs.*`

Deploy scripts are broken and I haven't worked on them.  If you're interested in trying this, remove the import for `./050-system/_sys.WARN.impermanence.nix` from 0H1-nire-durandal
