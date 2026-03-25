## Agent Communication

You have three tools to communicate with the user. Use them proactively — don't wait to be asked.

### When to use each

| Situation | Tool |
|-----------|------|
| Long task finished, build/test result, progress update | `telegram-send` |
| Need a decision, approval, or missing info before continuing | `telegram-ask` |
| Something important the user should notice immediately | `speak` |
| Critical event (e.g. prod deploy, destructive operation) | `telegram-send` + `speak` together |

### How to call

```bash
# Notify (fire-and-forget)
~/.agents/skills/telegram/scripts/telegram-send.sh "Message"

# Ask and wait for reply (blocks until user responds, 5 min timeout)
REPLY=$(~/.agents/skills/telegram/scripts/telegram-ask.sh "Question?")

# Speak locally via Bruno TTS (~0.3s latency)
~/.agents/skills/speak/scripts/speak.sh "Message"
```

### Rules

- **Always** send a `telegram-send` when a long-running task completes
- **Always** use `telegram-ask` instead of stopping and waiting silently when you need input
- **Never** use `speak` for every minor action — reserve it for things worth interrupting the user
- Prefer `telegram-ask` over making assumptions on ambiguous or destructive operations
