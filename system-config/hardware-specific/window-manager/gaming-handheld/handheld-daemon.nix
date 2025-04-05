{
    ...
}:

{
    services.handheld-daemon = {
    # if you're coming here from github search looking for ways to make HHD work,
    #     I need you to understand that the TDP control is currently mired in nixpkgs
    #     if you want it to work, it needs some work that I cannot do.
        enable      = true;
        user        = "elly";
        ui.enable   = true;
    };
}
