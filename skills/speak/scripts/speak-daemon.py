#!/usr/bin/env python3
# speak-daemon.py — warm TTS daemon
# Loads KittenTTS once, then reads text from a named pipe and speaks it.
# Stays alive indefinitely; managed by launchd.

import os
import sys
import subprocess
import tempfile

PIPE_PATH = "/tmp/speak-pipe"
VOICE = os.environ.get("SPEAK_VOICE", "Bruno")

# Suppress HuggingFace warning
os.environ.setdefault("HF_HUB_DISABLE_IMPLICIT_TOKEN", "1")

from kittentts import KittenTTS

tts = KittenTTS()
print(f"[speak-daemon] Ready. Voice: {VOICE}", flush=True)

# Create named pipe if it doesn't exist
if os.path.exists(PIPE_PATH):
    os.remove(PIPE_PATH)
os.mkfifo(PIPE_PATH)

try:
    while True:
        # Open pipe in read mode (blocks until a writer connects)
        with open(PIPE_PATH, "r") as pipe:
            for line in pipe:
                text = line.strip()
                if not text:
                    continue
                print(f"[speak-daemon] Speaking: {text}", flush=True)
                with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                    tmp_path = f.name
                try:
                    tts.generate_to_file(text, tmp_path, voice=VOICE)
                    subprocess.run(["afplay", tmp_path], check=True)
                finally:
                    if os.path.exists(tmp_path):
                        os.remove(tmp_path)
finally:
    if os.path.exists(PIPE_PATH):
        os.remove(PIPE_PATH)
