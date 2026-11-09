# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: snmp_exporter: polls the `ts-hive` QNAP over SNMPv3 for
# prometheus.nix's `qnap` job. Standard MIBs only so far; QNAP's own disk
# and volume tables wait on the NAS's MIB file (see "Not yet" below).
#
# Credentials are not in the Nix store. The unit reads
# /persist/secrets/snmp-exporter.env (same /persist/secrets home as
# grafana's secret_key), which must contain, one per line:
#     QNAP_SNMP_USER=...
#     QNAP_SNMP_AUTH_PASS=...
#     QNAP_SNMP_PRIV_PASS=...
# Until that file exists the unit fails to start; nothing else depends on it.
# The exporter expands `${VAR}` in the config itself
# (--config.expand-environment-variables, added by `environmentFile`).
#
# Not yet: QNAP's enterprise tables (disk status and temperature, volume
# status, fans). Their OIDs come from the NAS's own MIB (Control Panel ->
# SNMP -> download MIB), not from memory. Generate a module from it with
# snmp_exporter's generator, add it to `modules` below, and add the disk
# alerts to qnap-alerts.nix.
{
    nixos = {
        services.prometheus.exporters.snmp = {
            enable = true;

            # Loopback, same reasoning as node-exporter.nix.
            listenAddress = "127.0.0.1";

            environmentFile = "/persist/secrets/snmp-exporter.env";

            configuration = {
                auths.qnap_v3 = {
                    version        = 3;
                    username       = "\${QNAP_SNMP_USER}";
                    security_level = "authPriv";
                    password       = "\${QNAP_SNMP_AUTH_PASS}";
                    auth_protocol  = "SHA";
                    # The QNAP only offers DES for privacy. Weak cipher; the
                    # NAS's SNMP allow list is the real protection.
                    priv_protocol  = "DES";
                    priv_password  = "\${QNAP_SNMP_PRIV_PASS}";
                };

                modules.qnap = {
                    walk = [
                        "1.3.6.1.2.1.1.3"          # sysUpTime
                        "1.3.6.1.2.1.25.2.3.1"     # hrStorageTable
                        "1.3.6.1.2.1.31.1.1.1"     # ifXTable
                    ];
                    metrics = [
                        {
                            name = "sysUpTime";
                            oid  = "1.3.6.1.2.1.1.3";
                            type = "gauge";
                            help = "Time since the SNMP agent started, in hundredths of a second - 1.3.6.1.2.1.1.3";
                        }
                    ]
                    ++ map (m: {
                        inherit (m) name oid;
                        type    = "gauge";
                        help    = "${m.name} - ${m.oid}";
                        indexes = [ { labelname = "hrStorageIndex"; type = "gauge"; } ];
                        lookups = [ {
                            labels    = [ "hrStorageIndex" ];
                            labelname = "hrStorageDescr";
                            oid       = "1.3.6.1.2.1.25.2.3.1.3";
                            type      = "DisplayString";
                        } ];
                    }) [
                        { name = "hrStorageAllocationUnits"; oid = "1.3.6.1.2.1.25.2.3.1.4"; }
                        { name = "hrStorageSize";            oid = "1.3.6.1.2.1.25.2.3.1.5"; }
                        { name = "hrStorageUsed";            oid = "1.3.6.1.2.1.25.2.3.1.6"; }
                    ]
                    ++ map (m: {
                        inherit (m) name oid;
                        type    = "counter";
                        help    = "${m.name} - ${m.oid}";
                        indexes = [ { labelname = "ifIndex"; type = "gauge"; } ];
                        lookups = [ {
                            labels    = [ "ifIndex" ];
                            labelname = "ifName";
                            oid       = "1.3.6.1.2.1.31.1.1.1.1";
                            type      = "DisplayString";
                        } ];
                    }) [
                        { name = "ifHCInOctets";  oid = "1.3.6.1.2.1.31.1.1.1.6"; }
                        { name = "ifHCOutOctets"; oid = "1.3.6.1.2.1.31.1.1.1.10"; }
                    ];
                };
            };
        };
    };
}
