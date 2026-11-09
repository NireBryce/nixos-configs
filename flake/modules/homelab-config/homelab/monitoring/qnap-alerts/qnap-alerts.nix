# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: Prometheus alert rules for the `ts-hive` QNAP, from the metrics
# snmp-exporter.nix collects. Routing is alertmanager.nix's.
#
# The volume rule's `hrStorageDescr` match is a guess at how QTS names
# data volumes; check it against `hrStorageDescr` in the exporter output
# once the NAS answers, and fix the regex. Disk status, disk temperature
# and RAID state rules are not here yet: they need QNAP's own MIB
# (snmp-exporter.nix).
{
    nixos = {
        services.prometheus.rules = [
            (builtins.toJSON {
                groups = [ {
                    name = "qnap";
                    rules = [
                        {
                            alert  = "QnapUnreachable";
                            expr   = ''up{job="qnap"} == 0'';
                            "for"  = "5m";
                            labels = { area = "qnap"; severity = "warning"; };
                            annotations = {
                                summary     = "ts-hive does not answer SNMP.";
                                description = "Check the NAS is up, SNMP is enabled and still allows UDP 161 from nire-cube, and /persist/secrets/snmp-exporter.env on cube holds the current credentials (systemctl status prometheus-snmp-exporter).";
                            };
                        }
                        {
                            alert  = "QnapVolumeAlmostFull";
                            expr   = ''hrStorageUsed{job="qnap",hrStorageDescr=~"/share/.*"} / hrStorageSize{job="qnap",hrStorageDescr=~"/share/.*"} > 0.90'';
                            "for"  = "15m";
                            labels = { area = "qnap"; severity = "warning"; };
                            annotations = {
                                summary     = "ts-hive volume {{ $labels.hrStorageDescr }} is over 90% full.";
                                description = "Free space or expand the volume before restic backups from cube start failing.";
                            };
                        }
                    ];
                } ];
            })
        ];
    };
}
