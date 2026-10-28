# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki
{
    homeManager = { pkgs, ... }: {
        # package summary: qpwgraph -- PipeWire patchbay for audio/MIDI routing
        # virtual mixer
        home.packages = with pkgs; [
            qpwgraph
        ];
    };
}
