# ELK Backup (placed in /opt/jeylogscat)

Files placed in `/opt/jeylogscat`:

- `backup-elk.sh`: Script that rsyncs ELK config dirs to `/opt/jeylogscat/backups/YYYYMMDDTHHMMSSZ` and appends a short entry to `/opt/jeylogscat/ELK_USAGE_GUIDE.md`.
- `install-cron.sh`: Helper to install a user crontab entry running the backup daily at 02:00.
- `push-to-nas.sh`: Push helper that prefers SSH key-based rsync and falls back to CIFS using `/etc/syno_cred` (root-only).

Quick start:

1. Make scripts executable (if not already):

```bash
sudo chmod +x /opt/jeylogscat/backup-elk.sh
# ELK Backup (stored in /opt/jeylogscat)

This repository contains scripts to create local ELK configuration/data snapshots and push
them to a Synology NAS. Backups are created as root (to access system dirs) but snapshots
are chowned to the `jeyriku` user so push operations run unprivileged with an SSH key.

Files
- `backup-elk.sh` — creates timestamped snapshot directories under `/opt/jeylogscat/backups`
	and appends a short entry to `ELK_USAGE_GUIDE.md`.
- `push-to-nas.sh` — pushes the newest snapshot to the NAS using SSH key-based `rsync`. Falls
	back to CIFS only if absolutely necessary (requires `/etc/syno_cred` root-only file).
- `verify-backup.sh` — lightweight verification helper.
- `ELK_USAGE_GUIDE.md` — human-facing notes and change log.

Quick usage

- Make sure scripts are executable:

```bash
sudo chmod +x /opt/jeylogscat/*.sh
```

- Dry-run a backup (no changes):

```bash
DRYRUN=1 /opt/jeylogscat/backup-elk.sh
```

- Run backup+push immediately (systemd service):

```bash
sudo systemctl start elk-backup.service
sudo journalctl -u elk-backup.service -n 200 --no-pager
```

Scheduling (recommended)

The preferred scheduler is a systemd timer that runs the existing `elk-backup.service` at
02:00 each night. To enable the timer:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now elk-backup.timer
sudo systemctl status elk-backup.timer --no-pager
```

I created `/etc/systemd/system/elk-backup.timer` and set `OnCalendar=*-*-* 02:00:00` so the
backup runs nightly at 02:00 and `Persistent=true` so missed runs are executed at boot if
needed.

SSH key and push behavior

- The push helper prefers the per-user NAS key `/home/jeyriku/.ssh/id_ed25519_jeynas01`.
- Backups are chowned to `jeyriku` after creation so `rsync` can run as that user without
	root-owned files interfering.

Logging and troubleshooting

- Backup and push activity is appended to `/opt/jeylogscat/backup.log`.
- If a push fails with rsync errors, inspect `/opt/jeylogscat/backup.log` and the systemd
	journal for `elk-backup.service`.

Security notes

- Do not store NAS credentials in user-readable files. Prefer SSH key-based automation.
- If CIFS fallback is required, store credentials in `/etc/syno_cred` with root-only
	permissions and the format:

```
username=YOUR_NAS_USER
password=YOUR_PASSWORD
```

Restore notes

- To restore a file or directory from a snapshot, copy from the desired
	`/opt/jeylogscat/backups/<TIMESTAMP>/...` location back to the target path. Verify
	ownership and permissions after restore.

Contact

If you want me to change scheduling, switch to a different NAS path, or adjust rsync
options, tell me which option and I will update the scripts and the timer.

Git housekeeping

- A `.gitignore` file has been added to exclude Synology/macOS artifacts and common
	runtime logs (for example: `.DS_Store`, `@eaDir/`, `/tmp/` and `*.log`).
