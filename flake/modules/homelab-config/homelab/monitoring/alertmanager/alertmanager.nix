# This is a dirs-as-categories module file, which means its name is its
# filename minus the .nix suffix, and its category is the name of the folder
# it belongs to.
# https://github.com/NireBryce/dirs-as-categories/wiki

# summary: Alertmanager: receives alerts from Prometheus's rules
# (runner-alerts.nix, qnap-alerts.nix) and routes them to a receiver.
# Loopback only; grafana.nix reads it through an Alertmanager datasource
# for viewing and silencing.
#
# The `default` receiver below has no notification config, so alerts are
# visible in Grafana (Alerting -> Active notifications) but nothing is
# sent anywhere. Add the channel (email, ntfy, webhook, ...) to that
# receiver; credentials go through sops, not this file.
{
    nixos = {
        services.prometheus.alertmanager = {
            enable        = true;
            listenAddress = "127.0.0.1";

            configuration = {
                route = {
                    receiver        = "default";
                    group_by        = [ "alertname" "area" ];
                    group_wait      = "30s";
                    group_interval  = "5m";
                    repeat_interval = "12h";
                };
                receivers = [ { name = "default"; } ];
            };
        };
    };
}
