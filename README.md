# claumunicate

Two-way communication between Claude Code agents and you — over Telegram and local voice.

## What it does

When Claude Code agents are running long tasks, they go silent. You don't know if they finished, got stuck, or need input. **claumunicate** fixes that.

Agents can:
- **Notify you on Telegram** when a task completes (fire-and-forget)
- **Ask you a question on Telegram and block until you reply** — no more agents making bad assumptions
- **Speak to you locally** via voice synthesis when something needs your immediate attention

## Architecture

```
Agent
  │
  ├── telegram-send   ──► Telegram Bot API (instant notification)
  │
  ├── telegram-ask    ──► Telegram Bot API (sends question)
  │                       writes /tmp/telegram-pending
  │                       polls /tmp/telegram-reply (5 min timeout)
  │                       returns reply text to stdout
  │                            ▲
  │                   telegram-poller (launchd daemon)
  │                       long-polls Telegram getUpdates
  │                       on reply → writes /tmp/telegram-reply
  │
  └── speak           ──► speak-daemon (launchd daemon, model warm)
                          KittenTTS → Bruno voice → afplay
                          ~0.3s latency after first load
```

## Skills

### `telegram`

| Script | Purpose |
|--------|---------|
| `telegram-send.sh "msg"` | Fire-and-forget Telegram notification |
| `telegram-ask.sh "question?"` | Block until user replies on Telegram (5 min timeout) |

Backed by a persistent polling daemon (`telegram-poller.sh`) managed by launchd. Uses exponential backoff (5s → 10s → ... → 5min) on API failures.

### `speak`

| Script | Purpose |
|--------|---------|
| `speak.sh "msg"` | Speak text aloud locally via KittenTTS |
| `speak.sh "msg" Jasper` | Use a specific voice |

Available voices: `Bella`, `Jasper`, `Luna`, `Bruno` (default), `Rosie`, `Hugo`, `Kiki`, `Leo`

Backed by a warm daemon (`speak-daemon.py`) that keeps the TTS model loaded. Falls back to direct synthesis if the daemon isn't running.

## Requirements

- macOS (uses `afplay`, `launchctl`, `launchd`)
- Claude Code
- Telegram bot token + your chat ID ([create a bot via @BotFather](https://t.me/botfather))
- Python 3.12+
- Homebrew

Optional:
- [SwiftBar](https://swiftbar.app) for menu bar status indicator

## Installation

```bash
git clone https://github.com/teceer/claumunicate
cd claumunicate
bash install.sh
```

The installer will:
1. Install `jq`, `espeak-ng`, and `kittentts`
2. Copy skills to `~/.agents/skills/`
3. Prompt for your Telegram bot token and chat ID
4. Install and start launchd daemons
5. Install the SwiftBar menu bar plugin (if SwiftBar is present)
6. Add daemon warm-up to `~/.zlogin`

## Teaching agents to use it

Add the contents of `claude-md-snippet.md` to your `~/.claude/CLAUDE.md`:

```bash
cat claude-md-snippet.md >> ~/.claude/CLAUDE.md
```

This tells every Claude Code agent when and how to use each communication tool.

## Menu bar (SwiftBar)

Install [SwiftBar](https://swiftbar.app) (`brew install --cask swiftbar`) and point it at `~/Library/Application Support/SwiftBar/Plugins`.

The plugin shows:
- `🤖 ●` — both daemons running
- `🤖 ◑` — one daemon down
- `🤖 ○` — both daemons stopped

Click to restart or stop individual daemons, or open logs.

## Manual daemon management

```bash
# Start
launchctl kickstart -k gui/$(id -u)/com.claude.telegram-poller
launchctl kickstart -k gui/$(id -u)/com.claude.speak-daemon

# Stop
launchctl bootout gui/$(id -u)/com.claude.telegram-poller
launchctl bootout gui/$(id -u)/com.claude.speak-daemon

# Logs
tail -f ~/.claude/logs/telegram-poller.log
tail -f ~/.claude/logs/speak-daemon.log
```

## License

MIT
