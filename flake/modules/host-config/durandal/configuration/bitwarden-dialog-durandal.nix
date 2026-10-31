# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/dirs-as-categories/wiki
{ inputs, ... }:
{
    nixos = {
        # summary: Bitwarden's confirm dialog comes to front and takes focus on durandal.
        home-manager.users.elly = {
            # plasma-manager's HM module, scoped to durandal: tenacity keeps its
            # own (plasma-tenacity.nix); durandal never loaded it before this
            # file. Appended to elly's imports (set by enable-home-manager.nix)
            # rather than replacing it.
            imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

            programs.plasma.window-rules = [
                {
                    description = "Bitwarden windows (incl. the SSH-agent confirm dialog) come to front and take focus";
                    match = {
                        window-class = { value = "[Bb]itwarden"; type = "regex"; };
                        window-types = [ "dialog" "normal" ];
                    };
                    apply = {
                        focusstealing = 0; # kwin "None": new windows take focus immediately
                        acceptfocus = true;
                    };
                }
            ];
        };
    };
}
