{
  programs.zsh.zsh-abbr.abbreviations = {
      # ! WARN: unsure how globals work here
      # for now they're declared in the zsh config
      # but that's not declarative -- it saves them to abbr
      # even if you remove them from the zsh config
      "abbr remove"="abbr erase";
      "abbr rm"="abbr erase";
      "code-python"="code --profile=\"python\"";
      "code-rust"="code --profile=\"rust\"";
      "cs-zsh-bindings"="bindkey";
      "edit-zrc"="micro ~/.zshrc";
      "fb"="xplr";
      "fleek edit"="micro ~/.fleek.yml";
      "gsa"="git stash push";
      "highlighting-theme-default"="fast-theme sv-orple";
      "img-cat"="kitty +kitten icat";
      "kssh"="kitty +kitten ssh";
      "lcd"="cd ; ls";
      "linein-loopback"="amixer --card=1 sset 'Loopback Mixing' Enabled";
      "linein-loopback-disable"="amixer --card=1 sset 'Loopback Mixing' Disabled";
      "loopback"="pw-loopback";
      "mic-loopback"="pw-loopback";
      "nav"="xplr";
      "pamac uninstall"="pamac remove";
      "pamac-update-mirrors"="sudo pacman-mirrors -g";
      "pm"="pamac";
      "ssh-jellyfin-catball"="ssh erin@media.computer.garden -p 8022";
      "sudo pamac uninstall"="sudo pamac remove";
      "sudo pm"="pamac";
      "ttt"="bash _util/a11y/talon/run.sh";
      "wh"="wormhole";
      "whence"="type -a";
      "zsh-keymap"="bindkey";
      "nosrbd-d"="git add . && sudo nixos-rebuild test --flake .#nire-durandal";
    };
}
