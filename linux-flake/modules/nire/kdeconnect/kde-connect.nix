{ self, inputs, ...}:
{ flake.modules.nixos.kdeconnect = 
{ ... }: 
{
    # todo: shouldn't this be a service?
    programs.kdeconnect = {
        enable  = true;      # kde connect
    };
}
;}
