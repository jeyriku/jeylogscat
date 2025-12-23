#!/usr/bin/env bash
set -euo pipefail

# Push local ELK backups to Synology NAS using SSH key (preferred).
# Falls back to CIFS mount using root-only /etc/syno_cred if key absent.

ENV_FILE="/home/jeyriku/.syno_env"
if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/home/jeyriku/.syno_env
  source "$ENV_FILE"
else
  echo "Missing $ENV_FILE" >&2
  exit 1
fi

SRC_DIR="/opt/jeylogscat/backups"
if [ ! -d "$SRC_DIR" ]; then
  echo "No backups found at $SRC_DIR" >&2
  exit 0
fi

# Choose the newest snapshot subdirectory to push (most recent modification time)
latest_dir="$(find "$SRC_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | awk '{print $2; exit}')"
if [ -z "$latest_dir" ]; then
  echo "No backup subdirectory found in $SRC_DIR" >&2
  exit 0
fi
SRC_TO_PUSH="${latest_dir%/}/"

TARGET_DIR="$syno_share/$(hostname)-elk-backups"

# Prefer the NAS-specific per-user key, fall back to older key name if present
SSH_KEY_NEW="/home/jeyriku/.ssh/id_ed25519_jeynas01"
SSH_KEY_OLD="/home/jeyriku/.ssh/id_ed25519_jeylogscat"
if [ -f "$SSH_KEY_NEW" ]; then
  SSH_KEY="$SSH_KEY_NEW"
elif [ -f "$SSH_KEY_OLD" ]; then
  SSH_KEY="$SSH_KEY_OLD"
else
  SSH_KEY=""
fi

if [ -n "$SSH_KEY" ]; then
  RSYNC_SSH=( -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" )
  echo "Pushing $SRC_TO_PUSH -> $syno_user@$syno_ip:$TARGET_DIR/$(basename \"$SRC_TO_PUSH\")/"
  rsync "${RSYNC_SSH[@]}" -avz --delete "$SRC_TO_PUSH" "$syno_user@$syno_ip:$TARGET_DIR/$(basename \"$SRC_TO_PUSH\")/"
  exit 0
fi

# CIFS fallback using root-only credential file
CREDFILE_ROOT="/etc/syno_cred"
if [ -f "$CREDFILE_ROOT" ]; then
  MOUNT_POINT="/tmp/jey_nas_mount"
  mkdir -p "$MOUNT_POINT"
  REMOTE_SHARE="//${syno_ip}${syno_share}"
  sudo mount -t cifs "$REMOTE_SHARE" "$MOUNT_POINT" -o credentials="$CREDFILE_ROOT",iocharset=utf8 || { echo "CIFS mount failed" >&2; exit 1; }
  rsync -av --delete "$SRC_TO_PUSH" "$MOUNT_POINT/$(basename "$TARGET_DIR")/"
  sudo umount "$MOUNT_POINT"
  exit 0
fi

echo "No SSH key found and no /etc/syno_cred available; cannot push to NAS" >&2
exit 1
