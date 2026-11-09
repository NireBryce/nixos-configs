# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: snmp_exporter: polls the `ts-hive` QNAP over SNMPv3 for
# prometheus.nix's `qnap` job. Standard MIBs only so far; QNAP's own disk
# and volume tables wait on the NAS's MIB file (see "Not yet" below).
#
# Credentials are not in the Nix store. The sops key `snmp-exporter-env`
# (secrets.yaml) holds an env file as a multi-line string:
#     snmp-exporter-env: |
#         QNAP_SNMP_USER=...
#         QNAP_SNMP_AUTH_PASS=...
#         QNAP_SNMP_PRIV_PASS=...
# No quotes around values, and no spaces, `#` or `$` in them (systemd
# parses the file). The key must exist in secrets.yaml before cube
# switches, or activation fails. The exporter expands `${VAR}` in the
# config itself (--config.expand-environment-variables, added by
# `environmentFile`).
#
# QNAP's own tables come from the NAS's MIB (downloaded from Control Panel
# -> SNMP, "QTS-MIB" v2.0, enterprise 55062, branch qutshero = .2): the
# OIDs below are copied from it, not from memory, and the older 24681 tree
# is not what this MIB describes. Not yet verified against the running
# NAS; the first thing to check after a switch is that
# `storagepoolStatus` appears at all (qnap-alerts.nix alerts if it doesn't).
# Status columns the MIB types as free text (diskStatus, raidStatus) come
# out as info metrics whose label is the NAS's own string; qnap-alerts.nix
# has no rule on them until a real value has been seen.
{
    nixos = { config, lib, ... }: let
        # QTS-MIB: enterprises.qnap(55062).qutshero(2); storage = .10,
        # system = .12.
        storage = "1.3.6.1.4.1.55062.2.10";
        system  = "1.3.6.1.4.1.55062.2.12";

        scalar = name: oid: {
            inherit name oid;
            type = "gauge";
            help = "${name} - ${oid}";
        };

        # One column of a table: `idx` is the index label, `lookup` an
        # optional { name, oid } text column that becomes a label.
        column = { idx, lookup ? null }: { name, oid, type ? "gauge" }: {
            inherit name oid type;
            help    = "${name} - ${oid}";
            indexes = [ { labelname = idx; type = "gauge"; } ];
        } // lib.optionalAttrs (lookup != null) {
            lookups = [ {
                labels    = [ idx ];
                labelname = lookup.name;
                inherit (lookup) oid;
                type      = "DisplayString";
            } ];
        };

        disk = column { idx = "diskIndex"; lookup = { name = "diskModel"; oid = "${storage}.2.1.4"; }; };
        raid = column { idx = "raidIndex"; lookup = { name = "raidName";  oid = "${storage}.5.1.3"; }; };
        pool = column { idx = "storagepoolIndex"; };
        fan  = column { idx = "sysFanIndex"; lookup = { name = "sysFanDescr"; oid = "${system}.9.1.2"; }; };
    in {
        # Root-owned (the default): the unit reads it as root.
        sops.secrets.snmp-exporter-env = { };

        services.prometheus.exporters.snmp = {
            enable = true;

            # Loopback, same reasoning as node-exporter.nix.
            listenAddress = "127.0.0.1";

            environmentFile = config.sops.secrets.snmp-exporter-env.path;

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
                        "${storage}.2"             # diskTable
                        "${storage}.5"             # raidTable
                        "${storage}.7"             # storagepoolTable
                        "${system}.9"              # systemFanTable
                        "${system}.10"             # cpuTemperature
                        "${system}.11"             # systemTemperature
                        "${system}.12"             # systemCPU-Usage
                        "${system}.19"             # sysPowerStatus
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
                    ]
                    # QTS-MIB, from here down.
                    ++ map disk [
                        { name = "diskStatus";      oid = "${storage}.2.1.7"; type = "DisplayString"; }
                        { name = "diskTemperature"; oid = "${storage}.2.1.8"; }
                        { name = "diskCapacity";    oid = "${storage}.2.1.9"; }
                    ]
                    ++ map raid [
                        { name = "raidStatus";   oid = "${storage}.5.1.4"; type = "DisplayString"; }
                        { name = "raidCapacity"; oid = "${storage}.5.1.5"; }
                        { name = "raidLevel";    oid = "${storage}.5.1.7"; type = "DisplayString"; }
                    ]
                    # storagepoolStatus: negative is error, not ready or
                    # warning; 0 is ready; positive values are working
                    # states such as scrubbing (the MIB lists both the QuTS
                    # and QuTS hero meanings).
                    ++ map pool [
                        { name = "storagepoolCapacity"; oid = "${storage}.7.1.3"; }
                        { name = "storagepoolFreeSize"; oid = "${storage}.7.1.4"; }
                        { name = "storagepoolStatus";   oid = "${storage}.7.1.5"; }
                    ]
                    ++ map fan [
                        { name = "sysFanSpeed"; oid = "${system}.9.1.3"; }
                    ]
                    ++ [
                        (scalar "cpuTemperature"    "${system}.10")
                        (scalar "systemTemperature" "${system}.11")
                        (scalar "systemCPUUsage"    "${system}.12")
                        # failed = -1, ok = 0
                        (scalar "sysPowerStatus"    "${system}.19")
                    ];
                };
            };
        };
    };
}
