{ self, inputs, ...}:
{ 
flake.modules.homeManager.ellyHomeManager ={
    # TODO: this needs to exclude every host for now, which is not a workable solution!
    # list `[ ]` of all modules under 'self.modules.nixos.*'
    imports = builtins.attrValues (builtins.removeAttrs self.modules.homeManager [ "ellyHomeManager" ]);
};
}
