{ 
    nire.hardware =
    { inputs, ... }:
    {
        provides = {
            amdcpu = { imports = [ (inputs.import-tree ./_/amd/amdgpu) ]; };
            
            amdgpu = { imports = [ (inputs.import-tree ./_/amd/amdcpu) ]; };
            
            amd = { imports = [ (inputs.import-tree ./_/amd) ]; };
        };
    };
}
