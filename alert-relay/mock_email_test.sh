#!/usr/bin/env bash
set -eu

# Mock email send test for relay and MTA
RELAY_LOG="/var/log/syslog-alert-relay/relay.log"
TEST_TO=${1:-syslog@jeyriku.net}

echo "Running mock email test to $TEST_TO"

printf 'From: syslog-relay-test@example.local
To: %s
Subject: MOCK-EMAIL-TEST

Mock email test from $(hostname) at $(date)
' "$TEST_TO" | /usr/sbin/sendmail -oi "$TEST_TO"

echo "Checking mail queue (mailq) and relay log..."

if command -v mailq >/dev/null 2>&1; then
  echo "--- mailq ---"
  mailq || true
fi

echo "--- last relay log lines ---"
sudo tail -n 50 "$RELAY_LOG" 2>/dev/null || true

echo "Mock email test completed"
