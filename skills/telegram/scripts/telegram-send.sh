#!/usr/bin/env bash
# telegram-send.sh — fire-and-forget message to Telegram
# Usage: telegram-send.sh "Message text"

set -euo pipefail

CONFIG="${HOME}/.claude/.telegram-config"
if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config not found at $CONFIG. Run setup.sh first." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG"

MESSAGE="${1:-}"
if [[ -z "$MESSAGE" ]]; then
  echo "ERROR: No message provided." >&2
  echo "Usage: telegram-send.sh \"Your message\"" >&2
  exit 1
fi

RESPONSE=$(curl -s -X POST \
  "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${MESSAGE}")

OK=$(echo "$RESPONSE" | jq -r '.ok')
if [[ "$OK" != "true" ]]; then
  echo "ERROR: Telegram API error: $(echo "$RESPONSE" | jq -r '.description')" >&2
  exit 1
fi

exit 0
