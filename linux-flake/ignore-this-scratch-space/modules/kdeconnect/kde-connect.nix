{ nire.kde-connect.nixos = 
{ ... }: 
{
    # todo: shouldn't this be a service?
    programs.kdeconnect = {
        enable  = true;      # kde connect
    };
}
;}
