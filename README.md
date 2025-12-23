Jeylogscat: backup & syslog tooling
=================================

This folder contains scripts and helpers used to collect backup health lines and to manage network syslog ingestion:

- `push-syslog-to-devices.sh` — push syslog configuration to network devices (Cisco/Juniper/ASA).
- `create-kibana-network-pattern.sh` — helper to create Kibana index pattern and saved search.
- `monitor-backup-health.sh` — tails `backup-health.log` and verifies lines are indexed to Elasticsearch.
- `monitor-email-listener.sh` — watches the monitor log and sends email alerts for WARN/ERROR lines.
- `send-syslog-email.sh` — sends email notifications using the system MTA; configured to use `syslog@jeyriku.net` as sender.

Recent changes (2025-12-22):

- Added `send-syslog-email.sh` and `monitor-email-listener.sh` to notify `syslog@jeyriku.net` on monitor alerts.
- Created a systemd unit `monitor-backup-health-email.service` to run the email notifier as user `jeyriku`.
- Configured Postfix to relay outgoing mail through `ssl0.ovh.net` (SMTPS) using the provided credentials.

Backup & restore
----------------

To create a backup archive of this folder and upload it to the NAS `jeynas01`, run (as root or with sudo):

```bash
DATE=$(date +%F)
sudo tar -C / -czf /tmp/jeylogscat-backup-${DATE}.tar.gz opt/jeylogscat
scp /tmp/jeylogscat-backup-${DATE}.tar.gz jeynas01:~/
sha256sum /tmp/jeylogscat-backup-${DATE}.tar.gz
ssh jeynas01 "sha256sum ~/jeylogscat-backup-${DATE}.tar.gz"
```

To restore on a host (careful — will overwrite files under `/opt/jeylogscat`):

```bash
scp jeynas01:~/jeylogscat-backup-2025-12-22.tar.gz /tmp/
sudo tar -C / -xzf /tmp/jeylogscat-backup-2025-12-22.tar.gz
```

Security
--------

- `/etc/postfix/sasl_passwd` contains relay credentials and must be mode 600.
- `/etc/default/monitor-backup-health` contains `ELASTIC_PASSWORD` and is secured to 0600 root:root.

Contact
-------

For questions about these scripts, contact syslog@jeyriku.net.

Remote backup location
----------------------

Backups for this host are stored on `jeynas01` under:

```
/volume1/JeyFiles/Jeremie/Informatique/Lab@Home/BackupSrv/jeysrv03/elk
```

When copying backups with `scp`, you may use `-o StrictHostKeyChecking=no` the first time to accept the NAS host key automatically.

$(cat /home/jeyriku/README-jeylogscat.md)

Expect fallback (Cisco/Juniper)
-------------------------------

Le script `push-syslog-to-devices.sh` tente d'abord une connexion non-interactive (`ssh` / `sshpass`).
Si celle-ci échoue, il bascule automatiquement vers des helpers Expect pour gérer :

- l'acceptation de la clé hôte (`Are you sure you want to continue connecting`),
- les invites de mot de passe (`password:` ou "user's password:"),
- l'élévation `enable` sur Cisco lorsque nécessaire.

Fichiers concernés :

- `/opt/jeylogscat/auto_syslog_expect.exp` — automation générique pour ASA/Juniper/Cisco
- `/opt/jeylogscat/cisco_check_expect.exp` — fallback de vérification pour Cisco (post-check)
- `/opt/jeylogscat/diag_expect.exp` — utilitaire de diagnostic interactif

Rapports
--------

Après exécution, un rapport consolidé est créé sous `/opt/jeylogscat/push-syslog-report-<date>.txt`.
Les logs Expect par hôte sont enregistrés dans `/tmp/cisco_check_<host>.log` et `/tmp/diag_<host>.log`.
