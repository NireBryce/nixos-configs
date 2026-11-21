# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: Prometheus alert rules for cube's restic sqlite staging step, from
# the metrics restic.nix's backupPrepareCommand writes to node-exporter's
# textfile directory. Routing is alertmanager.nix's.
#
# The prepare step logs and continues when a `.backup` fails (failing the
# unit would skip the whole backup), so these rules are the only place a
# failed staged copy becomes visible.
{
    nixos = {
        services.prometheus.rules = [
            (builtins.toJSON {
                groups = [ {
                    name = "restic";
                    rules = [
                        {
                            # No `for` delay: the metric changes once per
                            # run, 24h apart, and Prometheus evaluates it
                            # often, so a delay only postpones the notice.
                            # The series stays 0 until the next successful
                            # run, so this does not flap.
                            alert  = "ResticSqliteStagingFailed";
                            expr   = "restic_sqlite_staging_ok == 0";
                            labels = { area = "backup"; severity = "warning"; };
                            annotations = {
                                summary     = "cube: the sqlite .backup of {{ $labels.db }} failed; its staged copy is missing from the restic snapshot.";
                                description = "sudo cat /var/cache/restic-backups-cube/prepare.log on cube names the failure. The rest of the backup still ran.";
                            };
                        }
                        {
                            # 172800 s = 2 days: one missed nightly run is
                            # tolerated (timer is 03:30 plus up to 30m).
                            # Covers a db failing repeatedly and a prepare
                            # step that stopped running at all.
                            alert  = "ResticSqliteStagingStale";
                            expr   = "time() - restic_sqlite_staging_last_success_timestamp_seconds > 172800";
                            labels = { area = "backup"; severity = "warning"; };
                            annotations = {
                                summary     = "cube: no successful sqlite staging of {{ $labels.db }} in over 2 days.";
                                description = "Check systemctl status restic-backups-cube and the timer on cube, then prepare.log under /var/cache/restic-backups-cube.";
                            };
                        }
                    ];
                } ];
            })
        ];
    };
}
