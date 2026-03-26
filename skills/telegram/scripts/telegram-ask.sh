#!/usr/bin/env bash
# telegram-ask.sh — send a question and block until the user replies
# Usage: REPLY=$(telegram-ask.sh "Your question?")
# Exit 0 + reply text on success; exit 1 + "TIMEOUT" on 5-minute timeout

set -euo pipefail

CONFIG="${HOME}/.claude/.telegram-config"
if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found at $CONFIG. Run setup.sh first." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG"

QUESTION="${1:-}"
if [[ -z "$QUESTION" ]]; then
  echo "ERROR: No question provided." >&2
  echo "Usage: telegram-ask.sh \"Your question?\"" >&2
  exit 1
fi

# Append a static footer so it's clear Claude is blocked waiting for a reply
QUESTION="${QUESTION}

⏳ _Claude is waiting for your reply_"

PENDING_FILE="/tmp/telegram-pending"
REPLY_FILE="/tmp/telegram-reply"
TIMEOUT_SECONDS=300  # 5 minutes
POLL_INTERVAL=2      # check every 2 seconds

# Clean up any stale state from a previous interrupted call
rm -f "$PENDING_FILE" "$REPLY_FILE"

# Send the question via Telegram
RESPONSE=$(curl -s -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${QUESTION}" \
  --data-urlencode "parse_mode=Markdown")

OK=$(echo "$RESPONSE" | jq -r '.ok')
if [[ "$OK" != "true" ]]; then
  echo "ERROR: Telegram API error: $(echo "$RESPONSE" | jq -r '.description')" >&2
  exit 1
fi

# Signal to the poller that we are waiting
echo "$QUESTION" > "$PENDING_FILE"

# Poll for the reply file
ELAPSED=0
while [[ $ELAPSED -lt $TIMEOUT_SECONDS ]]; do
  if [[ -f "$REPLY_FILE" ]]; then
    REPLY=$(cat "$REPLY_FILE")
    rm -f "$REPLY_FILE"
    echo "$REPLY"
    exit 0
  fi
  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# Timeout — clean up pending signal
rm -f "$PENDING_FILE"
echo "TIMEOUT"
exit 1
