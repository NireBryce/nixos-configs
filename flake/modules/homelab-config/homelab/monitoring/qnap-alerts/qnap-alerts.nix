# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: Prometheus alert rules for the `ts-hive` QNAP, from the metrics
# snmp-exporter.nix collects. Routing is alertmanager.nix's.
#
# The metrics come from QNAP's own MIB (snmp-exporter.nix). There is no rule
# on diskStatus or raidStatus yet: the MIB types them as free text and gives
# no values, so a rule needs a real string from the NAS first (look at
# `diskStatus` and `raidStatus` in the exporter output, then alert on any
# label other than the healthy one).
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
                                description = "Check the NAS is up, SNMP is enabled and still allows UDP 161 from nire-cube, and the snmp-exporter-env sops secret holds the current credentials (systemctl status prometheus-snmp-exporter).";
                            };
                        }
                        {
                            # Would also fire if the NAS answers SNMP but not
                            # under the QTS-MIB subtree this config walks.
                            alert  = "QnapMetricsMissing";
                            expr   = ''up{job="qnap"} == 1 unless on() storagepoolStatus{job="qnap"}'';
                            "for"  = "15m";
                            labels = { area = "qnap"; severity = "warning"; };
                            annotations = {
                                summary     = "ts-hive answers SNMP but QNAP's storage metrics are missing.";
                                description = "Walk 1.3.6.1.4.1.55062 on the NAS (snmpwalk with the exporter's credentials). If it is empty, the NAS serves another MIB tree and snmp-exporter.nix needs its OIDs changed.";
                            };
                        }
                        {
                            # The status is negative for error, not ready and
                            # warning, 0 for ready; positive values are working
                            # states such as scrubbing, which are not alerts.
                            alert  = "QnapStoragePoolUnhealthy";
                            expr   = ''storagepoolStatus{job="qnap"} < 0'';
                            "for"  = "5m";
                            labels = { area = "qnap"; severity = "critical"; };
                            annotations = {
                                summary     = "ts-hive storage pool {{ $labels.storagepoolIndex }} is in an error, not-ready or warning state.";
                                description = "Open the QNAP's Storage & Snapshots page. The status value is in storagepoolStatus (QTS-MIB lists the meanings).";
                            };
                        }
                        {
                            alert  = "QnapStoragePoolAlmostFull";
                            expr   = ''1 - storagepoolFreeSize{job="qnap"} / storagepoolCapacity{job="qnap"} > 0.90'';
                            "for"  = "15m";
                            labels = { area = "qnap"; severity = "warning"; };
                            annotations = {
                                summary     = "ts-hive storage pool {{ $labels.storagepoolIndex }} is over 90% full.";
                                description = "Free space or expand the pool before restic backups from cube start failing.";
                            };
                        }
                        {
                            alert  = "QnapDiskHot";
                            expr   = ''diskTemperature{job="qnap"} > 55'';
                            "for"  = "10m";
                            labels = { area = "qnap"; severity = "warning"; };
                            annotations = {
                                summary     = "ts-hive disk {{ $labels.diskModel }} is over 55 C.";
                                description = "Check the NAS's fans and airflow. 55 C suits spinning disks; SSDs run hotter, so raise the threshold if an SSD trips it.";
                            };
                        }
                        {
                            alert  = "QnapPowerFailed";
                            expr   = ''sysPowerStatus{job="qnap"} < 0'';
                            "for"  = "2m";
                            labels = { area = "qnap"; severity = "critical"; };
                            annotations = {
                                summary     = "ts-hive reports a power supply failure.";
                                description = "sysPowerStatus is -1 (failed). Check the NAS's power supplies and its status page.";
                            };
                        }
                    ];
                } ];
            })
        ];
    };
}
