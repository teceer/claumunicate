#!/usr/bin/env bash
# claude-agents.5s.sh — SwiftBar plugin showing Claude agent daemon status
# Filename format: <name>.<interval><unit>.sh — refreshes every 5 seconds

telegram_running=false
speak_running=false

# Check if telegram poller has a live PID in launchctl
if launchctl list 2>/dev/null | awk '$3 == "com.claude.telegram-poller" && $1 != "-" {found=1} END {exit !found}'; then
  telegram_running=true
fi

# Check if speak daemon has a live PID in launchctl
if launchctl list 2>/dev/null | awk '$3 == "com.claude.speak-daemon" && $1 != "-" {found=1} END {exit !found}'; then
  speak_running=true
fi

# --- Menu bar icon ---
# Show a single compact indicator: green dot if both up, yellow if partial, red if both down
if $telegram_running && $speak_running; then
  echo "🤖 ●"
elif $telegram_running || $speak_running; then
  echo "🤖 ◑"
else
  echo "🤖 ○"
fi

# --- Dropdown menu ---
echo "---"
echo "Claude Agent Daemons"
echo "---"

if $telegram_running; then
  echo "✅ Telegram Poller — running"
else
  echo "❌ Telegram Poller — stopped | bash='launchctl kickstart -k gui/$(id -u) com.claude.telegram-poller' terminal=false refresh=true"
fi

if $speak_running; then
  echo "✅ Speak Daemon (Bruno) — running"
else
  echo "❌ Speak Daemon — stopped | bash='launchctl kickstart -k gui/$(id -u) com.claude.speak-daemon' terminal=false refresh=true"
fi

echo "---"
echo "Restart Telegram Poller | bash='launchctl kickstart -k gui/$(id -u) com.claude.telegram-poller' terminal=false refresh=true"
echo "Restart Speak Daemon    | bash='launchctl kickstart -k gui/$(id -u) com.claude.speak-daemon' terminal=false refresh=true"
echo "---"
echo "Stop Telegram Poller | bash='launchctl bootout gui/$(id -u)/com.claude.telegram-poller' terminal=false refresh=true"
echo "Stop Speak Daemon    | bash='launchctl bootout gui/$(id -u)/com.claude.speak-daemon' terminal=false refresh=true"
echo "---"
echo "View Telegram Log | bash='open ${HOME}/.claude/logs/telegram-poller.log' terminal=false"
echo "View Speak Log    | bash='open ${HOME}/.claude/logs/speak-daemon.log' terminal=false"
