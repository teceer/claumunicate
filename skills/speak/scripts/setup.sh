#!/usr/bin/env bash
# setup.sh — install dependencies for the speak skill

set -euo pipefail

echo "=== Speak Skill Setup ==="
echo ""

# Check espeak-ng
if ! command -v espeak-ng &>/dev/null && ! brew list espeak-ng &>/dev/null 2>&1; then
  echo "Installing espeak-ng..."
  brew install espeak-ng
else
  echo "espeak-ng: ok"
fi

# Install kittentts
echo "Installing kittentts..."
pip3 install "kittentts @ https://github.com/KittenML/KittenTTS/releases/download/0.8.1/kittentts-0.8.1-py3-none-any.whl"

chmod +x "$(dirname "$0")/speak.sh"

# Symlink
SYMLINK="${HOME}/.claude/skills/speak"
if [[ ! -L "$SYMLINK" ]]; then
  ln -s "${HOME}/.agents/skills/speak" "$SYMLINK"
  echo "Symlink created: $SYMLINK"
fi

echo ""
echo "=== Setup complete ==="
echo "Test with:"
echo "  ~/.agents/skills/speak/scripts/speak.sh \"Hello from Claude\""
