---
name: telegram
description: Send notifications and ask questions to the user over Telegram. Use telegram-send for fire-and-forget updates; use telegram-ask when you need a blocking decision or approval from the user before continuing.
metadata:
  author: local
  version: "1.0.0"
---

# Telegram Communication Skill

Communicate with the user over Telegram in two modes: informational sends and blocking questions that wait for a reply.

## When to Use `telegram-send` (non-blocking)

Use when you want to inform the user but do NOT need a reply:

- A long task finished successfully
- A build or test run completed
- A file was generated or deployed
- Progress checkpoint ("50% done, starting phase 2")
- Any status update that requires no decision

## When to Use `telegram-ask` (blocking)

Use when you need the user's answer before you can continue:

- Ambiguous requirements: "Should I use TypeScript or JavaScript here?"
- Destructive operations: "I'm about to delete 47 files. Confirm? (yes/no)"
- Design decisions: "Which approach would you prefer: A or B?"
- Approvals: "Ready to push to production. Approve?"
- Missing information you cannot infer

Do NOT use `telegram-ask` for things you can reasonably decide yourself.

## How to Call the Scripts

### telegram-send (informational, non-blocking)

```bash
~/.agents/skills/telegram/scripts/telegram-send.sh "Your message here"
```

Returns immediately. Exit code 0 on success, non-zero on failure.

### telegram-ask (blocking, waits for reply)

```bash
REPLY=$(~/.agents/skills/telegram/scripts/telegram-ask.sh "Your question here?")
```

Blocks until the user replies via Telegram or a 5-minute timeout elapses.
- On success: exits 0, `$REPLY` contains the user's message text
- On timeout: exits 1, `$REPLY` contains `TIMEOUT`

## Formatting Tips

- Keep messages concise — Telegram renders plain text well
- For binary decisions, suggest the expected answers: "Reply YES or NO"
- Prefix agent messages with a context label: "[Claude] Task complete: ..."

## Prerequisites

The poller daemon must be running. To check:

```bash
launchctl list | grep telegram-poller
```

To start it if not running:

```bash
launchctl load ~/Library/LaunchAgents/com.claude.telegram-poller.plist
```

First-time setup: run `~/.agents/skills/telegram/scripts/setup.sh`
