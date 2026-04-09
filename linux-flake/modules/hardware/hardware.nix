{ 
    nire.hardware =
    { inputs, ... }:
    {
        provides = {
            amdcpu = { imports = [ (inputs.import-tree ./_/amd/amdcpu) ]; };

            amdgpu = { imports = [ (inputs.import-tree ./_/amd/amdgpu) ]; };
            
            amd = { imports = [ (inputs.import-tree ./_/amd) ]; };
        };
    };
}
