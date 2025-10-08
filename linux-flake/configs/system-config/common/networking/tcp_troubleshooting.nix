{
    ...
}:
{
    networking.interfaces.wlp4s0.ipv4.routes = [
        {
            address = "0.0.0.0";
            prefixLength = 0;
            via = "192.168.0.1";
            options.quickack = "1";
        }
    ];
}
