#!/usr/bin/env bash
set -euo pipefail

# ELK backup script placed in /opt/jeylogscat
# - Rsyncs configured ELK config directories into a timestamped folder under /opt/jeylogscat/backups
# - Appends a short entry to /opt/jeylogscat/ELK_USAGE_GUIDE.md (must be writable by user)

DEST_DIR="/opt/jeylogscat/backups"
LOGFILE="/opt/jeylogscat/backup.log"
RETENTION_DAYS=14

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
OUT_DIR="$DEST_DIR/$TIMESTAMP"

# Directories to backup (adjust as needed)
declare -a PATHS=(
  "/etc/elasticsearch"
  "/etc/logstash"
  "/etc/kibana"
  "/var/lib/elasticsearch"
  "/etc/ssl"
)

# Allow overriding dry-run by env var DRYRUN=1
DRYRUN=${DRYRUN:-0}
RSYNC_OPTS=( -aHAX --numeric-ids --delete --partial --progress )
if [ "$DRYRUN" != "0" ]; then
  RSYNC_OPTS+=(--dry-run)
fi

mkdir -p "$OUT_DIR"
mkdir -p "$(dirname "$LOGFILE")"

echo "Backup started: $TIMESTAMP" | tee -a "$LOGFILE"

for p in "${PATHS[@]}"; do
  if [ -e "$p" ]; then
    dest="$OUT_DIR/$(echo "$p" | sed 's#^/##')"
    mkdir -p "$dest"
    echo "rsyncing $p -> $dest" | tee -a "$LOGFILE"
    rsync "${RSYNC_OPTS[@]}" "$p"/ "$dest"/ 2>&1 | tee -a "$LOGFILE"
  else
    echo "Skipped missing path: $p" | tee -a "$LOGFILE"
  fi
done

# Ensure the created backup is owned by the `jeyriku` account
# so the push-to-nas script (which runs as that user) can read and push files
# without encountering root-owned permission errors.
if [ -d "$OUT_DIR" ]; then
  chown -R jeyriku:jeyriku "$OUT_DIR" 2>/dev/null || true
  chmod -R u+rwX,go-rwx "$OUT_DIR" 2>/dev/null || true
  echo "Changed ownership to jeyriku and restricted permissions on $OUT_DIR" | tee -a "$LOGFILE"
fi

echo "Pruning backups older than $RETENTION_DAYS days in $DEST_DIR" | tee -a "$LOGFILE"
find "$DEST_DIR" -maxdepth 1 -type d -mtime +$RETENTION_DAYS -print0 | xargs -r -0 rm -rf -- 2>/dev/null || true

# Append a short entry to the existing doc in /opt/jeylogscat/
DOC_PATH="/opt/jeylogscat/ELK_USAGE_GUIDE.md"
if [ -w "$DOC_PATH" ] || [ ! -e "$DOC_PATH" -a -w "/opt/jeylogscat" ]; then
  cat >> "$DOC_PATH" <<EOF

## Backup entry - $TIMESTAMP

- Backed up paths: ${PATHS[*]}
- Destination: $OUT_DIR
- Dry-run: $DRYRUN
- Log: $LOGFILE

EOF
  echo "Appended backup entry to $DOC_PATH" | tee -a "$LOGFILE"
else
  echo "Warning: cannot write to $DOC_PATH; skipping append" | tee -a "$LOGFILE"
fi

echo "Backup finished: $TIMESTAMP" | tee -a "$LOGFILE"

exit 0
