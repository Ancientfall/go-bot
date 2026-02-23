# Gobot — Always-On AI Telegram Agent

An always-on Telegram agent powered by Claude with multi-agent routing, proactive check-ins, persistent memory, voice calls, and morning briefings. Supports three deployment modes: local desktop, cloud VPS, or hybrid (recommended).

**Created by [Goda Go](https://youtube.com/@GodaGo)** | [Autonomee Community](https://skool.com/autonomee)

## What It Does

```
                          ┌── Local (Claude Code CLI + subscription)
You ──▶ Telegram ──▶ Bot ─┤
                          └── VPS  (Anthropic API + API key)
                                │
                                ├── Same code, same features everywhere:
                                │   MCP Servers, Skills, Hooks, CLAUDE.md
                                │
                                └── Supabase (shared memory, goals, history)
```

- **Relay**: Send messages on Telegram, get Claude responses back (and connect from Google Chat, Microsoft Teams, Discord, WhatsApp, Slack, and more)
- **Multi-Agent**: Route messages to specialized agents via Telegram forum topics
- **Multi-Bot Identities**: Each agent can have its own Telegram bot for visual separation
- **Board Meetings**: `/board` command triggers multi-agent discussion with synthesis
- **Cross-Agent**: Agents consult each other mid-conversation automatically
- **Memory**: Persistent facts, goals, and conversation history via Supabase
- **Image Storage**: Photos stored persistently with AI-generated descriptions, tags, and semantic search
- **Smart Routing**: Messages auto-classified by complexity — Haiku (fast), Sonnet (medium), Opus (powerful)
- **Streaming Progress**: Complex tasks show real-time tool usage and progress updates in Telegram
- **Call-to-Task**: Phone calls auto-detect actionable tasks and execute them with live progress updates
- **Proactive**: Smart check-ins that know when to reach out (and when not to)
- **Briefings**: Daily morning summary with pluggable data sources (goals, calendar, email, news, tasks)
- **Voice**: Text-to-speech replies, voice transcription, and phone calls
- **Human-in-the-Loop**: Claude asks for confirmation via inline buttons before taking actions
- **Hybrid Mode**: VPS catches messages 24/7, forwards to your local machine when it's awake
- **Auto-Deploy**: Push to GitHub, VPS pulls and restarts automatically

## What's New

### v2.6.0 — Multi-Bot Agent Identities + Board Meetings
Each agent can now have its own Telegram bot — messages from Research, Finance, Content etc. appear from separate bot accounts. New `/board` command triggers a full multi-agent discussion on any topic. Agents can consult each other mid-conversation. All optional, fully backward compatible.

### v2.5.3 — ZIP-to-Git Upgrade
`bun run upgrade` connects ZIP downloads to the official repo. Future updates are just `git pull`.

### v2.5.0 — Reliability & VPS Hardening
Fixed 6 production bugs (voice context, dedup, intent detection). Added VPS hardening docs and raised default API budget to $15.

### v2.3.0 — Call-to-Task Auto-Execution
Phone calls auto-detect actionable tasks and execute them with live progress updates.

### v2.1.0 — Smart Routing + Streaming Progress
Messages auto-classified by complexity (Haiku/Sonnet/Opus). Complex tasks show real-time progress.

### v2.0.0 — VPS Gateway + Hybrid Mode
Always-on VPS processing with Anthropic API, hybrid forwarding, human-in-the-loop, auto-deploy.

See [CHANGELOG.md](CHANGELOG.md) for full details.

## Deployment Modes

| Mode | How It Works | Cost |
|------|-------------|------|
| **Local** | Runs on your machine using Claude Code CLI | Claude Pro subscription to get started ($20/mo), Max for full power ($100-200/mo) |
| **VPS** (24/7) | Runs on a cloud server using Anthropic API | VPS (~$5/mo) + API costs vary by usage and model selection |
| **Hybrid** (recommended) | VPS always on, forwards to local when your machine is awake | VPS + API costs + subscription |

### Same Code, Full Power — Everywhere

Claude Code CLI works with an `ANTHROPIC_API_KEY` environment variable. When set, it uses the Anthropic API (pay-per-token). Without it, Claude Code uses your subscription authentication. Both modes give you **all** Claude Code features: MCP servers, skills, hooks, CLAUDE.md, built-in tools.

This means: clone the repo on your VPS, install Claude Code, set your API key, and run `bun run start`. Same experience as your laptop. One codebase everywhere.

### Why Hybrid?

Your laptop sleeps. Your VPS doesn't. With hybrid mode:
- Messages are always processed, even at 3am
- When your local machine is awake, it handles everything via your Claude Code CLI (subscription)
- When it sleeps, VPS takes over with API key (pay-per-token)
- Both have full Claude Code power — MCP servers, skills, hooks, everything

## Quick Start

### Prerequisites

- **macOS, Windows, or Linux**
- **[Bun](https://bun.sh)** runtime (`curl -fsSL https://bun.sh/install | bash`)
  - After installing, restart your terminal or run: `export BUN_INSTALL="$HOME/.bun" && export PATH="$BUN_INSTALL/bin:$PATH"`
- **[Claude Code](https://claude.ai/claude-code)** CLI installed and authenticated
- **Windows/Linux only**: [PM2](https://pm2.keymetrics.io/) for daemon services (`npm install -g pm2`)

### Setup

```bash
# Clone the repo (recommended — enables future updates via git pull)
git clone https://github.com/autonomee/gobot.git
cd gobot

# Install dependencies
bun install

# Open with Claude Code — it reads CLAUDE.md and guides you through setup
claude
```

### Downloaded as ZIP?

If you downloaded the ZIP instead of cloning, your bot works fine — but you can't pull updates. Fix it with one command:

```bash
bun run upgrade
```

This connects your existing install to the official repo without touching your `.env`, profile, or any config. Future updates are then just `git pull origin master`.

Claude Code reads the `CLAUDE.md` file and walks you through a guided conversation to:

1. Create a Telegram bot via BotFather
2. Set up Supabase for persistent memory
3. Personalize your profile and agents
4. Customize agents + optional multi-bot identities and `/board` meetings
5. Test the bot
6. Configure always-on services
7. Set up optional integrations (voice, fallback LLMs)
8. Deploy to VPS (optional)

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Runtime | [Bun](https://bun.sh) |
| Telegram SDK | [grammY](https://grammy.dev) |
| AI (Local) | [Claude Code](https://claude.ai/claude-code) CLI |
| AI (VPS) | [Anthropic Messages API](https://docs.anthropic.com/en/api/messages) |
| Database | [Supabase](https://supabase.com) (PostgreSQL + Storage) |
| Always-On | macOS launchd / PM2 + cron / VPS webhook mode |
| Voice (opt.) | [ElevenLabs](https://elevenlabs.io) |
| Phone Calls (opt.) | ElevenLabs + [Twilio](https://twilio.com) |
| Transcription (opt.) | [Google Gemini](https://ai.google.dev) |
| Fallback LLM (opt.) | [OpenRouter](https://openrouter.ai) / [Ollama](https://ollama.ai) |
| External Tools | Your MCP servers (Gmail, Calendar, Notion, etc.) |

## Architecture

### Local Mode
```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Telegram    │────▶│  Gobot       │────▶│  Claude Code    │
│  (grammY)   │◀────│  (polling)   │◀────│  CLI Subprocess │
└─────────────┘     └──────┬───────┘     └─────────────────┘
                           │
                    ┌──────┴───────┐
                    │  Supabase    │
                    │  - Messages  │
                    │  - Memory    │
                    │  - Assets    │
                    │  - Logs      │
                    └──────────────┘
```

### VPS Mode (same code as local)
```
┌─────────────┐     ┌──────────────┐     ┌─────────────────────┐
│  Telegram    │────▶│  Gobot       │────▶│  Claude Code CLI    │
│  (grammY)   │◀────│  (polling)   │◀────│  + ANTHROPIC_API_KEY │
└─────────────┘     └──────┬───────┘     │                     │
                           │              │  ✅ MCP Servers      │
                    ┌──────┴───────┐     │  ✅ Skills           │
                    │  Supabase    │     │  ✅ Hooks            │
                    │  - Messages  │     │  ✅ CLAUDE.md        │
                    │  - Memory    │     │  ✅ Built-in Tools   │
                    │  - Assets    │     └─────────────────────┘
                    │  - Tasks     │
                    └──────────────┘
```

### Hybrid Mode
```
┌───────────┐     ┌──────────────────────────────────────────┐
│ Telegram  │     │  VPS (always on, Claude Code + API key)  │
│           │────▶│                                           │
│           │◀────│  Is local machine alive?                  │
└───────────┘     │  ├── YES → forward to local (subscription)│
                  │  └── NO  → process on VPS (API tokens)   │
                  │                                           │
                  │  Both have full Claude Code power:        │
                  │  MCP servers, skills, hooks, tools        │
                  └──────────────────┬───────────────────────┘
                                     │
                              ┌──────┴───────┐
                              │  Supabase    │
                              │  (shared)    │
                              └──────────────┘
```

## Learn to Build This

Step-by-step video walkthroughs for every module are available in the [Autonomee](https://skool.com/autonomee) community on Skool.

Also in this repo:
- [Changelog](CHANGELOG.md)
- [FAQ](docs/faq.md)
- [Architecture Deep Dive](docs/architecture.md)
- [Troubleshooting](docs/troubleshooting.md)

## Commands

```bash
# Local mode
bun run start              # Start bot (polling mode, uses Claude Code CLI)

# VPS mode
bun run vps                # Start VPS gateway (webhook mode, uses Anthropic API)

# Background services
bun run checkin            # Run smart check-in
bun run briefing           # Run morning briefing
bun run watchdog           # Run health check

# Setup & testing
bun run setup              # Install dependencies
bun run setup:launchd      # Configure launchd services (macOS)
bun run setup:services     # Configure services (Windows/Linux)
bun run setup:google       # Set up Google OAuth (Gmail + Calendar)
bun run setup:verify       # Full health check
bun run test:telegram      # Test Telegram connectivity
bun run test:supabase      # Test Supabase connectivity
bun run uninstall          # Remove all services
```

## VPS Hosting

Need a VPS? I recommend [Hostinger](https://hostinger.com?REFERRALCODE=1GODA06) — affordable, reliable, and works great for this bot. Use promo code **GODAGO** for a discount.

## Community

Join the [Autonomee](https://skool.com/autonomee) community on Skool for:
- Step-by-step video walkthroughs of every module
- Help with setup and customization
- Share your bot builds and integrations

## License

MIT

---

Built by [Goda Go](https://youtube.com/@GodaGo)

<!-- Updated February 19, 2026: Clarified deployment modes and authentication following Anthropic's January 2026 ToS enforcement. -->
