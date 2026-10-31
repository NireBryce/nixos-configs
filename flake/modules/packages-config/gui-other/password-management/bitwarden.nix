# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: bitwarden-desktop -- Bitwarden password manager desktop app
        # bitwarden - password manager https://bitwarden.com/
        #
        # The SSH agent (serves vault keys on ~/.bitwarden-ssh-agent.sock,
        # wired up as SSH_AUTH_SOCK by zsh.nix and bash.nix) is enabled
        # inside the app: Settings -> Security -> SSH agent. That flag is
        # app state in ~/.config/Bitwarden/data.json, which the app owns
        # and rewrites -- deliberately not managed from here.
        home.packages = with pkgs; [
            bitwarden-desktop
        ];

        # Keep the agent's host process alive from login onward: the agent
        # only exists while the app runs. --start-minimized matches what
        # the app's own start-on-login toggle writes, so do not also enable
        # that toggle (duplicate autostart entries; the single-instance lock
        # absorbs the second launch, but pick one source of truth).
        # XDG autostart is processed only by graphical session managers, so
        # a TTY or ssh login never launches this -- deliberately: the agent
        # belongs to the human tier, and headless contexts use the
        # per-machine agent keys (agent-keys.nix) instead.
        # home.file, not xdg.autostart.entries: that module gates on
        # xdg.autostart.enable, whose true state makes Home Manager own
        # ~/.config/autostart -- one desktop file does not justify adopting
        # the whole directory.
        home.file.".config/autostart/bitwarden-ssh-agent.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Name=Bitwarden SSH agent
            Exec=bitwarden --start-minimized
            Terminal=false
            X-GNOME-Autostart-enabled=true
        '';
    };
}
