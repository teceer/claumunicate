#!/usr/bin/env bash
# telegram-poller.sh — long-polling daemon managed by launchd
# Reads updates from Telegram and writes replies to /tmp/telegram-reply
# when /tmp/telegram-pending exists (meaning an agent is waiting).

set -euo pipefail

CONFIG="${HOME}/.claude/.telegram-config"
if [[ ! -f "$CONFIG" ]]; then
  echo "$(date): ERROR: Config not found at $CONFIG" >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$CONFIG"

OFFSET_FILE="${HOME}/.claude/telegram-offset"
PENDING_FILE="/tmp/telegram-pending"
REPLY_FILE="/tmp/telegram-reply"
LONG_POLL_TIMEOUT=30  # seconds to wait for Telegram to return updates

get_offset() {
  if [[ -f "$OFFSET_FILE" ]]; then
    cat "$OFFSET_FILE"
  else
    echo "0"
  fi
}

save_offset() {
  echo "$1" > "$OFFSET_FILE"
}

echo "$(date): Telegram poller started"

# Exponential backoff state
BACKOFF=5       # current wait in seconds
BACKOFF_MAX=300 # cap at 5 minutes

while true; do
  OFFSET=$(get_offset)

  # Long-poll Telegram getUpdates (max-time slightly exceeds server-side timeout)
  RESPONSE=$(curl -s --max-time $((LONG_POLL_TIMEOUT + 5)) \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" \
    -d "offset=${OFFSET}" \
    -d "timeout=${LONG_POLL_TIMEOUT}" \
    -d "allowed_updates=[\"message\"]" 2>/dev/null || echo '{"ok":false,"result":[]}')

  OK=$(echo "$RESPONSE" | jq -r '.ok' 2>/dev/null || echo "false")
  if [[ "$OK" != "true" ]]; then
    echo "$(date): WARNING: getUpdates failed, retrying in ${BACKOFF}s" >&2
    sleep "$BACKOFF"
    # Double the backoff, capped at BACKOFF_MAX
    BACKOFF=$(( BACKOFF * 2 < BACKOFF_MAX ? BACKOFF * 2 : BACKOFF_MAX ))
    continue
  fi

  # Successful poll — reset backoff
  BACKOFF=5

  # Process each update
  UPDATE_COUNT=$(echo "$RESPONSE" | jq '.result | length' 2>/dev/null || echo "0")
  if [[ "$UPDATE_COUNT" -eq 0 ]]; then
    continue
  fi

  for i in $(seq 0 $((UPDATE_COUNT - 1))); do
    UPDATE=$(echo "$RESPONSE" | jq -c ".result[$i]")

    UPDATE_ID=$(echo "$UPDATE" | jq -r '.update_id')
    CHAT_ID=$(echo "$UPDATE" | jq -r '.message.chat.id // empty')
    MESSAGE_TEXT=$(echo "$UPDATE" | jq -r '.message.text // empty')

    # Always advance offset past this update to avoid reprocessing
    NEXT_OFFSET=$((UPDATE_ID + 1))
    save_offset "$NEXT_OFFSET"

    # Only handle messages from the configured chat
    if [[ "$CHAT_ID" != "$TELEGRAM_CHAT_ID" ]]; then
      continue
    fi

    echo "$(date): Received message from chat $CHAT_ID: $MESSAGE_TEXT"

    # Only act if an agent is waiting for a reply
    if [[ -f "$PENDING_FILE" ]] && [[ -n "$MESSAGE_TEXT" ]]; then
      echo "$(date): Writing reply to $REPLY_FILE"
      echo "$MESSAGE_TEXT" > "$REPLY_FILE"
      rm -f "$PENDING_FILE"
    fi
  done
done
