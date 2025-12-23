#!/usr/bin/env bash
set -euo pipefail

CRON_SCHEDULE="0 2 * * *" # daily at 02:00
SCRIPT="/opt/jeylogscat/backup-elk.sh"
LOG="/opt/jeylogscat/cron.log"

if [ ! -x "$SCRIPT" ]; then
  echo "Making $SCRIPT executable"
  chmod +x "$SCRIPT" || true
fi

# Install into user crontab
CRON_ENTRY="$CRON_SCHEDULE DRYRUN=0 $SCRIPT >> $LOG 2>&1"

# Avoid duplicate entries
( crontab -l 2>/dev/null | grep -v -F "$SCRIPT" || true; echo "$CRON_ENTRY" ) | crontab -

echo "Installed cron job: $CRON_ENTRY"
