#!/usr/bin/env bash
set -euo pipefail

# Complete ELK backup script
# - creates a timestamped snapshot under /opt/jeylogscat/backups
# - rsyncs critical ELK configuration and runtime files into the snapshot
# - copies the repository README into the snapshot
# - chowns snapshot to jeyriku and restricts permissions

BASE=/opt/jeylogscat
BACKUPS=${BASE}/backups
TS=$(date -u +"%Y%m%dT%H%M%SZ")
SNAP=${BACKUPS}/${TS}
LOG=${BASE}/backup.log

declare -a PATHS=(
  /etc/elasticsearch
  /etc/logstash
  /etc/kibana
  /etc/filebeat
  /etc/systemd/system/elk-backup.service
  /etc/systemd/system/elk-backup.timer
  /opt/jeylogscat/README.md
  /opt/jeylogscat
  /var/lib/logstash
  /var/lib/elasticsearch
)

mkdir -p "$SNAP"
echo "Starting full ELK backup: $TS" | tee -a "$LOG"

for p in "${PATHS[@]}"; do
  if [ -e "$p" ]; then
    echo "rsync: $p -> $SNAP/" | tee -a "$LOG"
    rsync -aHAX --numeric-ids --delete --exclude='lost+found' --one-file-system "$p" "$SNAP/" 2>&1 | tee -a "$LOG"
  else
    echo "skipping missing: $p" | tee -a "$LOG"
  fi
done

# If README exists in /opt/jeylogscat, ensure it's copied at top-level
if [ -f /opt/jeylogscat/README.md ]; then
  cp -a /opt/jeylogscat/README.md "$SNAP/README.md" 2>/dev/null || true
fi

# Simple pruning: keep 14 latest snapshots
cd "$BACKUPS"
ls -1dt */ 2>/dev/null | sed -n '15,$p' | xargs -r -I{} rm -rf -- {}

# Fix ownership and permissions for pushing as jeyriku
chown -R jeyriku:$(id -gn jeyriku) "$SNAP" || true
chmod -R u+rwX,go-rwx "$SNAP" || true

echo "Snapshot created: $SNAP" | tee -a "$LOG"
echo "$TS" > "$BASE/last_backup_ts"

exit 0
