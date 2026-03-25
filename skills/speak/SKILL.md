---
name: speak
description: Speak text aloud on the local Mac using KittenTTS voice synthesis. Use when you want to audibly announce something to the user — task completions, alerts, or anything that warrants an audio notification beyond a silent Telegram message.
metadata:
  author: local
  version: "1.0.0"
---

# Speak Skill

Synthesize text to speech locally using KittenTTS and play it via `afplay`. Fully offline, no API key required.

## When to Use

- Task completed after a long operation — announce it audibly
- Something important happened that the user should hear immediately
- Paired with `telegram-send` for critical alerts (notify + speak)
- Any time a visual notification alone isn't enough

Do NOT use for every minor action — reserve for meaningful moments worth interrupting the user for.

## How to Call

```bash
~/.agents/skills/speak/scripts/speak.sh "Your text here"
```

Returns immediately after playback finishes. Exit code 0 on success.

## Pairing with Telegram

For important events, combine both:

```bash
~/.agents/skills/telegram/scripts/telegram-send.sh "Deploy complete"
~/.agents/skills/speak/scripts/speak.sh "Deploy complete"
```

## Prerequisites

- `espeak-ng`: `brew install espeak-ng`
- `kittentts`: run `~/.agents/skills/speak/scripts/setup.sh` to install
