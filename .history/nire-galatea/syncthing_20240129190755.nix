{
# services
  services.syncthing = {
    enable = true;
    dataDir = "/home/elly/syncthing";
    openDefaultPorts = true;
    configDir = "/home/elly/.config/syncthing";
    user = "elly";
    group = "users";
    guiAddress = "0.0.0.0:8384";
    overrideDevices = true; 
    overrideFolders = true;
    settings.folders = { 
      "code" = { 
        path = "/home/elly/code";
        devices = [ "nire-galatea" ];
        versioning = {
          type = "staggered";
          params = { 
            cleanInterval = "3600";
            maxAge = "15768000";
          };
        };
      };
      "sync" = {
        path = "/home/elly/sync";
        devices = [ "nire-lysithea" "nire-durandal" "nire-tenacity" "nire-sif" "nire-iona"];
        versioning = { 
          type = "simple";
          params = { keep = 5; };
        };
      }; 
    };  
    settings.devices = {
      "nire-durandal"    = { id = "5FTZQAS-KEE5XI5-BHCQNFQ-E3S2QEA-KVOQAID-Q55I2Y3-YH4WM6N-2LA7XAN"; };
      "nire-sif"         = { id = "4AWC42H-PXBIBQB-OZDROYJ-6WZVR6V-WXBZ4AU-UFH6EJM-WWZWA3X-XFQ3TAS"; };
      # "nire-galatea"     = { id = "PCIR5O7-73WQN63-DXAVK3Z-G7QEWUY-R2BFF5P-TVCYFKU-LBRI3N3-IA477QL"; };
      "nire-lysithea"    = { id = "L7HXAZQ-DTHEPV7-TSOD6QR-O46ZIQW-EULYYJV-JNUV6E2-23FXC64-QOYELQW"; };
      "nire-iona"        = { id = "BEC6DM5-5Y6L6ZP-OSMJ7MQ-HQIWW25-WIG24JV-BOQZGQW-LIFZPA5-VEXKAAZ"; };
      "nire-tenacity"    = { id = "K73HCBQ-G2GS23G-BXNMXEO-ILOBGXD-MTLWL6Z-BI2S5XR-HX4OCBN-6VMP5AN"; };
    };  
    # declarative = {
    # };
  };
}
