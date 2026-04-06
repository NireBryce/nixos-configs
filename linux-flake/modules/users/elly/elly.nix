{
    nire.elly = { inputs, den, ... }: {

        provides = {
            all = { imports = [ (inputs.import-tree ./_) ]; };
            git = { imports = [ (inputs.import-tree ./_/git) ]; };
            session = { imports = [ (inputs.import-tree ./_/session) ]; };
            home-manager-settings = { imports = [ (inputs.import-tree ./_/home-manager-settings) ]; };
            user-settings = { imports = [ (inputs.import-tree ./_/user-settings) ]; };
        };
    };

    includes = [ 
            # # https://den.oeiuwq.com/guides/batteries/

            # den.proides.define-user
            # # Sets users.users.<name> on NixOS/Darwin 
            # # and home.username/home.homeDirectory for Home Manager. 
            # # Works in both host-user and standalone home contexts.
            
            # den.provides.primary-user
            # # Primary user:
            # # NixOS: adds wheel and networkmanager groups, sets isNormalUser.
            # # Darwin: sets system.primaryUser.
            # # WSL: sets defaultUser (if WSL is enabled).
        ];
}
