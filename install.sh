#!/usr/bin/env bash
# install.sh — one-shot installer for claumunicate
# Installs telegram + speak skills, SwiftBar plugin, and launchd daemons.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${HOME}/.agents/skills"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
LOG_DIR="${HOME}/.claude/logs"
PYTHON="/Library/Frameworks/Python.framework/Versions/3.12/bin/python3"

echo "=== claumunicate installer ==="
echo ""

# --- Dependencies ---
echo "Checking dependencies..."

if ! command -v jq &>/dev/null; then
  echo "Installing jq..."
  brew install jq
fi

if ! command -v espeak-ng &>/dev/null; then
  echo "Installing espeak-ng..."
  brew install espeak-ng
fi

if ! "$PYTHON" -c "import kittentts" &>/dev/null 2>&1; then
  echo "Installing kittentts..."
  pip3 install "kittentts @ https://github.com/KittenML/KittenTTS/releases/download/0.8.1/kittentts-0.8.1-py3-none-any.whl"
else
  echo "kittentts: ok"
fi

# --- Directories ---
mkdir -p "$SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "$LOG_DIR"

# --- Install skills ---
echo "Installing skills..."

cp -r "${REPO_DIR}/skills/telegram" "${SKILLS_DIR}/telegram"
cp -r "${REPO_DIR}/skills/speak" "${SKILLS_DIR}/speak"
chmod +x "${SKILLS_DIR}/telegram/scripts/"*.sh
chmod +x "${SKILLS_DIR}/speak/scripts/"*.sh "${SKILLS_DIR}/speak/scripts/"*.py

# Symlinks for Claude Code to discover the skills
ln -sf "${SKILLS_DIR}/telegram" "${CLAUDE_SKILLS_DIR}/telegram"
ln -sf "${SKILLS_DIR}/speak" "${CLAUDE_SKILLS_DIR}/speak"

echo "Skills installed."

# --- Telegram config ---
CONFIG_FILE="${HOME}/.claude/.telegram-config"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo ""
  echo "Telegram bot setup:"
  echo "  1. Message @BotFather on Telegram → /newbot"
  echo "  2. Copy the bot token"
  echo "  3. Send a message to your bot, then visit:"
  echo "     https://api.telegram.org/bot<TOKEN>/getUpdates"
  echo "     to find your chat ID (result[0].message.chat.id)"
  echo ""
  read -rp "Enter your Telegram Bot Token: " BOT_TOKEN
  read -rp "Enter your Telegram Chat ID: " CHAT_ID

  cat > "$CONFIG_FILE" <<EOF
TELEGRAM_BOT_TOKEN="${BOT_TOKEN}"
TELEGRAM_CHAT_ID="${CHAT_ID}"
EOF
  chmod 600 "$CONFIG_FILE"
  echo "Config written to $CONFIG_FILE"
else
  echo "Telegram config: already exists, skipping."
fi

# --- launchd plists ---
echo "Installing launchd daemons..."

cat > "${LAUNCH_AGENTS_DIR}/com.claude.telegram-poller.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.claude.telegram-poller</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>${SKILLS_DIR}/telegram/scripts/telegram-poller.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>${HOME}</string>
      <key>PATH</key>
      <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/telegram-poller.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/telegram-poller-error.log</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
  </dict>
</plist>
EOF

cat > "${LAUNCH_AGENTS_DIR}/com.claude.speak-daemon.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.claude.speak-daemon</string>
    <key>ProgramArguments</key>
    <array>
      <string>${PYTHON}</string>
      <string>${SKILLS_DIR}/speak/scripts/speak-daemon.py</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>${HOME}</string>
      <key>PATH</key>
      <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
      <key>SPEAK_VOICE</key>
      <string>Bruno</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/speak-daemon.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/speak-daemon-error.log</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
  </dict>
</plist>
EOF

# Start daemons
for service in com.claude.telegram-poller com.claude.speak-daemon; do
  launchctl bootout "gui/$(id -u)/${service}" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "${LAUNCH_AGENTS_DIR}/${service}.plist"
  launchctl kickstart -k "gui/$(id -u)/${service}"
done

echo "Daemons started."

# --- SwiftBar plugin ---
SWIFTBAR_PLUGINS="${HOME}/Library/Application Support/SwiftBar/Plugins"
if [[ -d "$SWIFTBAR_PLUGINS" ]]; then
  cp "${REPO_DIR}/swiftbar/claude-agents.5s.sh" "${SWIFTBAR_PLUGINS}/"
  chmod +x "${SWIFTBAR_PLUGINS}/claude-agents.5s.sh"
  echo "SwiftBar plugin installed."
else
  echo "SwiftBar not found — skipping menu bar plugin."
  echo "Install SwiftBar: brew install --cask swiftbar"
  echo "Then copy swiftbar/claude-agents.5s.sh to your SwiftBar plugins folder."
fi

# --- .zlogin ---
ZLOGIN="${HOME}/.zlogin"
if ! grep -q "com.claude.telegram-poller" "$ZLOGIN" 2>/dev/null; then
  cat >> "$ZLOGIN" <<'EOF'

# claumunicate — ensure Claude agent daemons are warm on login
launchctl kickstart -k gui/"$(id -u)"/com.claude.telegram-poller 2>/dev/null || true
launchctl kickstart -k gui/"$(id -u)"/com.claude.speak-daemon 2>/dev/null || true
EOF
  echo ".zlogin updated."
fi

echo ""
echo "=== Installation complete ==="
echo ""
echo "Test telegram:  ~/.agents/skills/telegram/scripts/telegram-send.sh 'Hello from Claude'"
echo "Test speak:     ~/.agents/skills/speak/scripts/speak.sh 'Hello from Claude'"
echo ""
echo "Add this to your CLAUDE.md to teach agents when to use these tools:"
echo "  cat ${REPO_DIR}/claude-md-snippet.md"
