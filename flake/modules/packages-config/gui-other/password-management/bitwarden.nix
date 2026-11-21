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
        # only exists while the app runs. Keep the app's own start-on-login
        # toggle (Settings -> App Settings) OFF. When on, the app writes a
        # second entry, ~/.config/autostart/bitwarden.desktop
        # (Exec=bitwarden --autostart), on every start. Both entries launch
        # at login and the single-instance lock does not absorb the second
        # one: the journal showed two full startups (two pids) in the same
        # second. With two instances on one profile, closing one closes the
        # other, and the survivor could then not be closed from the GUI.
        # Observed 2026-11-19; the link between the two instances and the
        # stuck close is inferred from the journal, not reproduced.
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
