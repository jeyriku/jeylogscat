#!/usr/bin/env bash
set -euo pipefail

LOGFILE="/opt/jeylogscat/backup.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "[verify-backup] start $TIMESTAMP" >> "$LOGFILE"

KEY="/home/jeyriku/.ssh/id_ed25519_jeylogscat"
ENV_FILE="/home/jeyriku/.syno_env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/home/jeyriku/.syno_env
  source "$ENV_FILE"
fi

BACKUP_ROOT="/opt/jeylogscat/backups"
if [ ! -d "$BACKUP_ROOT" ]; then
  echo "[verify-backup] no backups directory" >> "$LOGFILE"
  exit 0
fi

LATEST=$(find "$BACKUP_ROOT" -maxdepth 1 -type d -printf '%T@ %p\n' | sort -n | tail -n1 | cut -d' ' -f2-)
if [ -z "$LATEST" ]; then
  echo "[verify-backup] no backup folders found" >> "$LOGFILE"
  exit 0
fi

echo "[verify-backup] latest: $LATEST" >> "$LOGFILE"

REMOTE_DIR="$syno_share/$(hostname)-elk-backups"

if [ -f "$KEY" ]; then
  echo "[verify-backup] testing dry-run rsync to $syno_ip:$REMOTE_DIR" >> "$LOGFILE"
  RSYNC_SSH=( -e "ssh -i $KEY -o BatchMode=yes -o StrictHostKeyChecking=no" )
  if rsync "${RSYNC_SSH[@]}" -avz --delete --dry-run "$LATEST"/ "$syno_user@$syno_ip:$REMOTE_DIR/" &>> "$LOGFILE"; then
    echo "[verify-backup] dry-run rsync succeeded" >> "$LOGFILE"
  else
    echo "[verify-backup] dry-run rsync failed" >> "$LOGFILE"
  fi
else
  echo "[verify-backup] SSH key not found; cannot verify via rsync" >> "$LOGFILE"
fi

echo "[verify-backup] finished $TIMESTAMP" >> "$LOGFILE"

exit 0
