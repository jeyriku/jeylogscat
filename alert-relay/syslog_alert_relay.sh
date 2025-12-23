#!/usr/bin/env bash
set -u

# Relay Kibana server-log outputs to mail via local MTA with logging and locking
LOG_DIR="/var/log/syslog-alert-relay"
LOG_FILE="$LOG_DIR/relay.log"
KIBANA_LOG="/var/log/kibana/kibana.log"
MATCH='Syslog messages detected'
PIDFILE="/var/run/syslog-alert-relay.pid"

mkdir -p /opt/jeylogscat/alert-relay
mkdir -p "$LOG_DIR"

if [ ! -f "$KIBANA_LOG" ]; then
  echo "Kibana log not found: $KIBANA_LOG" >&2
  logger -t syslog-alert-relay "Kibana log not found: $KIBANA_LOG"
  exit 1
fi

exec 9>"$PIDFILE"
if ! flock -n 9; then
  echo "Another instance is running, exiting" | tee -a "$LOG_FILE"
  logger -t syslog-alert-relay "Another instance is running, exiting"
  exit 0
fi
echo $$ > "$PIDFILE"

trap 'rm -f "$PIDFILE"; exit' INT TERM EXIT

tail -F -n0 "$KIBANA_LOG" 2>/dev/null | while IFS= read -r line; do
  if printf '%s' "$line" | grep -q "$MATCH"; then
    ts="$(date --iso-8601=seconds)"
    echo "$ts $line" >> "$LOG_FILE"
    logger -t syslog-alert-relay "Matched alert: ${line:0:200}"
    # Send mail with the full log line; capture sendmail exit status
    if printf 'To: syslog@jeyriku.net\nSubject: [Kibana Alert] Syslog event detected\n\n%s\n' "$line" | /usr/sbin/sendmail -oi syslog@jeyriku.net; then
      echo "$ts sent OK" >> "$LOG_FILE"
    else
      echo "$ts sendmail failed" >> "$LOG_FILE"
      logger -t syslog-alert-relay "sendmail failed for alert"
    fi
  fi
done

rm -f "$PIDFILE"
trap - INT TERM EXIT
