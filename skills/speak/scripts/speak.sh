#!/usr/bin/env bash
# speak.sh — speak text via warm daemon (fast) or direct synthesis (fallback)
# Usage: speak.sh "Text to speak" [voice]

set -euo pipefail

PYTHON="/Library/Frameworks/Python.framework/Versions/3.12/bin/python3"
PIPE="/tmp/speak-pipe"
TEXT="${1:-}"
VOICE="${2:-Luna}"
SPEED="${3:-1.4}"

if [[ -z "$TEXT" ]]; then
  echo "ERROR: No text provided." >&2
  echo "Usage: speak.sh \"Text to speak\" [voice]" >&2
  exit 1
fi

# Fast path: daemon is running, just write to pipe
if [[ -p "$PIPE" ]]; then
  echo "$TEXT" > "$PIPE"
  exit 0
fi

# Slow path: synthesize directly
OUTPUT=$(mktemp /tmp/speak-XXXXXX.wav)
"$PYTHON" - "$TEXT" "$OUTPUT" "$VOICE" "$SPEED" <<'EOF'
import sys
from kittentts import KittenTTS
import os
os.environ.setdefault("HF_HUB_DISABLE_IMPLICIT_TOKEN", "1")

text, output_path, voice, speed = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
tts = KittenTTS()
tts.generate_to_file(text, output_path, voice=voice, speed=speed)
EOF

afplay "$OUTPUT"
rm -f "$OUTPUT"
