#!/usr/bin/env bash
set -euo pipefail

# Lightweight ELK backup health check
# - checks latest local snapshot
# - verifies ownership
# - verifies the same snapshot exists on the NAS via the jeyriku SSH key
# - appends a single-line JSON status to /opt/jeylogscat/backup-health.log

SRC_DIR=/opt/jeylogscat/backups
LOG=/opt/jeylogscat/backup-health.log
HOST=$(hostname -s)
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

latest=$(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk '{print $2; exit}') || true
status="ok"
error=""
size_bytes=0
snapshot_name=""

if [[ -z "$latest" ]]; then
  status="missing"
  error="no-local-snapshot"
else
  snapshot_name=$(basename "$latest")
  size_bytes=$(du -sb "$latest" 2>/dev/null | cut -f1 || echo 0)
  owner=$(stat -c '%U' "$latest" 2>/dev/null || echo "")
  if [[ "$owner" != "jeyriku" ]]; then
    status="warning"
    error="owner:$owner"
  fi
  # verify remote presence (use user's syno env and key)
  if [[ -f /home/jeyriku/.syno_env ]]; then
    # shellcheck disable=SC1090
    source /home/jeyriku/.syno_env || true
    remote_path="${syno_share}/${HOST}-elk-backups"
    if ! ssh -i /home/jeyriku/.ssh/id_ed25519_jeynas01 -o BatchMode=yes -o StrictHostKeyChecking=no "${syno_user}@${syno_ip}" "test -e \"${remote_path}/${snapshot_name}\"" 2>/dev/null; then
      status="missing_remote"
      error="remote-missing"
    fi
  else
    status="warning"
    error="no-syno-env"
  fi
fi

json="{\"host\":\"$HOST\",\"timestamp\":\"$TS\",\"snapshot\":\"$snapshot_name\",\"status\":\"$status\",\"error\":\"$error\",\"size\":$size_bytes}"
mkdir -p "$(dirname "$LOG")"
chown --no-dereference jeyriku:$(id -gn jeyriku) "$(dirname "$LOG")" 2>/dev/null || true
echo "$json" >> "$LOG"
echo "$json"
