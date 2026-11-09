# Monitoring the QNAP (`ts-hive`)

_Last modified: 2026-11-09_

Prometheus on `nire-cube` polls the QNAP over SNMPv3 and raises alerts on
what it reads. This page covers setting up the NAS side, checking that it
works, and what to do when an alert fires. How it is built and why is in
[monitoring](../config-structure/categories/monitoring.md). Written
2026-11-09; the NAS had not been queried yet, so the "first check" section
is the part still to confirm.

## Contents

- [What it does](#what-it-does)
- [NAS side](#nas-side)
- [Credentials](#credentials)
- [First check after a switch](#first-check-after-a-switch)
- [Alerts](#alerts)
- [Adding a disk or RAID status alert](#adding-a-disk-or-raid-status-alert)
- [See also](#see-also)
## What it does

- cube's `snmp-exporter` asks the NAS for disk, RAID, storage-pool, fan,
  power and temperature readings once a minute.
- Prometheus rules (`qnap-alerts.nix`) alert on a few of them. Alertmanager
  receives the alerts. Grafana shows them under **Alerting**.
- No notification channel is set up yet, so an alert is visible in Grafana
  and goes nowhere else.

## NAS side

1. Control Panel → Network & File Services → SNMP: enable the SNMP service on
   port 161.
2. Use SNMPv3: a read-only user, authentication SHA, privacy DES (the only
   privacy protocol this NAS offers). Leave the trap settings empty.
3. In the NAS's allow list, permit UDP 161 only from cube. cube reaches the NAS
   as `ts-hive` over the tailnet, so the source is cube's tailnet address.
4. The same page has a **Download SNMP MIB** button. The file is `NAS.mib`
   (`QTS-MIB`, enterprise 55062). It is not stored in the repo; the exporter's
   OIDs were copied from it.

## Credentials

The three SNMP values live in one sops key, `snmp-exporter-env`, an env file
stored as a multi-line string:

```yaml
snmp-exporter-env: |
    QNAP_SNMP_USER=<user>
    QNAP_SNMP_AUTH_PASS=<auth password>
    QNAP_SNMP_PRIV_PASS=<privacy password>
```

Edit it with `sops` on `secrets.yaml`. Do not quote the values, and avoid
spaces, `#` and `$` in them: systemd parses the file. To change a password,
change it on the NAS and in this key, then `just switch` on cube. Check the
key exists with `just read-sops-names`, which prints names only.

## First check after a switch

Run these on cube.

```sh
systemctl status prometheus-snmp-exporter
curl -s '127.0.0.1:9116/snmp?module=qnap&auth=qnap_v3&target=ts-hive' | grep -c '^storagepoolStatus'
```

- The exporter should be `active`. If it is not, read its journal: an
  authentication error means the user, hash or passwords differ from the
  NAS's.
- The count should be at least 1. A reply with `sysUpTime` but no
  `storagepoolStatus` means the NAS answers but not under the `QTS-MIB` tree
  (`1.3.6.1.4.1.55062`). The `QnapMetricsMissing` alert fires after 15
  minutes in that state. Walk the NAS to see what it serves:
  `nix shell nixpkgs#net-snmp -c snmpwalk -v3 …` with the exporter's
  credentials, starting at `1.3.6.1.4.1`, then fix the OIDs in
  `snmp-exporter.nix`.
- Prometheus should show the target up:
  `curl -s 127.0.0.1:9090/api/v1/query --data-urlencode 'query=up{job="qnap"}'`.

## Alerts

| Alert | Fires when | First thing to look at |
|---|---|---|
| `QnapUnreachable` | the scrape fails for 5 minutes | the NAS is on, SNMP is enabled, the allow list still has cube, the sops key is current |
| `QnapMetricsMissing` | the NAS answers but QNAP's storage metrics are absent for 15 minutes | the walk in "First check" |
| `QnapStoragePoolUnhealthy` | a pool's status is negative (error, not ready, warning) for 5 minutes | the NAS's Storage & Snapshots page. Positive statuses such as scrubbing do not alert. |
| `QnapStoragePoolAlmostFull` | a pool is over 90% full for 15 minutes | free or expand space before cube's restic backups fail |
| `QnapDiskHot` | a disk is over 55 °C for 10 minutes | fans and airflow. Raise the threshold for SSDs. |
| `QnapPowerFailed` | the power status is failed for 2 minutes | the NAS's power supplies |

## Adding a disk or RAID status alert

`diskStatus` and `raidStatus` are text in the MIB, and the MIB lists no
values, so there is no rule on them yet. To add one:

1. Read the real strings:
   `curl -s '127.0.0.1:9116/snmp?module=qnap&auth=qnap_v3&target=ts-hive' | grep -E '^(diskStatus|raidStatus)'`
   The string appears as a label, for example `diskStatus{diskStatus="…"} 1`.
2. Note the value for a healthy disk or array.
3. Add a rule to `qnap-alerts.nix` that fires for any other value, such as
   `diskStatus{job="qnap",diskStatus!="<healthy string>"}`, and update this
   table.

## See also

- [monitoring](../config-structure/categories/monitoring.md): how the stack is
  built.
- [Using Grafana](grafana.md): where the alerts show.
- [Backup runbook](backup-runbook.md): restic backs cube up to the same NAS.
