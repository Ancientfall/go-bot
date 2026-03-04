# GoBot — Always-On AI Telegram Agent

Always-on Telegram agent powered by Claude with multi-agent routing, proactive check-ins, morning briefings, and persistent memory via Supabase.

> **New here?** See `docs/setup-guide.md` for the full setup walkthrough (Phases 0-10).

## Repository & Git Workflow

**Source of truth:** `autonomee/gobot` (GitHub organization repo)

| Repo | Role | Status |
|------|------|--------|
| `autonomee/gobot` | Main repo — all work happens here | Active |
| `godagoo/gobot` | Personal archive (was the original) | Archived, read-only |

- **Autonomee Community team** (21 members) has **Write** access — push branches and create PRs
- Only admins (Goda, Sjotie) can merge to `master`
- Members **cannot** fork to personal accounts (org setting)

## Project Structure

```
src/
  bot.ts                    # Main relay daemon (local mode, polling)
  vps-gateway.ts            # VPS gateway (webhook mode, Anthropic API)
  smart-checkin.ts          # Proactive check-ins
  morning-briefing.ts       # Daily briefing
  watchdog.ts               # Health monitor
  lib/
    env.ts                  # Environment loader
    telegram.ts             # Telegram helpers
    claude.ts               # Claude Code subprocess (local mode) + streaming progress
    anthropic-processor.ts  # Anthropic API processor (VPS mode, direct API)
    agent-session.ts        # Agent SDK processor (VPS mode, full Claude Code)
    model-router.ts         # Complexity classifier + tiered model selection
    mac-health.ts           # Local machine health checking (hybrid mode)
    task-queue.ts           # Human-in-the-loop task management
    asset-store.ts          # Persistent image/file storage with AI descriptions
    supabase.ts             # Database client + async tasks + heartbeat
    memory.ts               # Facts, goals, intents
    fallback-llm.ts         # Backup LLM chain (OpenRouter/Ollama)
    bot-registry.ts         # Multi-bot agent identity routing
    capabilities.ts         # Agent capability definitions
    cross-agent.ts          # Cross-agent consultation logic
    knowledge-base.ts       # Shared knowledge base utilities
    ops-data.ts             # Operations data helpers
    board-data.ts           # Board meeting data aggregation
    voice.ts                # Gemini TTS + ElevenLabs phone calls
    transcribe.ts           # Gemini speech-to-text (file + buffer)
    invoice/                # Invoice processing pipeline
      index.ts              # Main entry point
      types.ts              # Invoice types
      extract.ts            # Data extraction from invoice files
      parse.ts              # Invoice parsing logic
      match.ts              # PO matching
      verify.ts             # Verification checks
      format.ts             # Output formatting
      processor.ts          # Orchestrates extract→parse→match→verify
      vendors.ts            # Vendor database/lookup
    data-sources/           # Pluggable morning briefing data
      types.ts              # DataSource interface
      index.ts              # Re-exports
      registry.ts           # Register, discover, fetch all
      google-auth.ts        # Google OAuth token refresh
      sources/
        goals.ts            # Supabase goals (built-in, always on)
        ops-briefing.ts     # Operations briefing data
        gemini-news.ts      # AI news via Gemini + Google Search
        grok-news.ts        # AI news via xAI Grok (fallback)
        gmail.ts            # Unread emails
        calendar.ts         # Today's events
        notion-tasks.ts     # Due/overdue tasks
        custom.example.ts   # Template for custom sources
  agents/
    base.ts                 # Agent interface, routing, topic map, cross-agent permissions
    index.ts                # Agent registry (exports all active agents)
    general.ts              # General Orchestrator — default assistant, cross-agent coordination
    critic.ts               # Critic — devil's advocate, stress-testing (internal)
    software.ts             # Software Engineering — full-stack coding, debugging, DevOps
    database.ts             # Database (Supabase) — schema, queries, migrations, RLS
    bp-docs.ts              # BP Documents — document creation, reports, SOPs
    bp-contracts.ts         # BP Contracts — MSAs, SOWs, vendor agreements, compliance
    bp-invoices.ts          # BP Invoices — invoice review, PO matching, discrepancies
    bp-finance.ts           # BP Finance & Budgets — budget tracking, forecasting, cost analysis
    coo.ts                  # COO agent (unregistered)
    cto.ts                  # CTO agent (unregistered)
    research.ts             # Research agent (legacy, unregistered)
    content.ts              # Content agent (legacy, unregistered)
    finance.ts              # Finance agent (legacy, unregistered)
    strategy.ts             # Strategy agent (legacy, unregistered)
    custom-agent.example.ts # Template for custom agents
config/
  profile.md               # User personalization (gitignored)
  profile.example.md       # Profile template
  schedule.json            # Check-in/briefing schedule (gitignored)
  schedule.example.json    # Default schedule template
  rates/                   # Rate configuration data
db/
  schema.sql               # Supabase database schema (IF NOT EXISTS — safe to re-run)
deploy.sh                  # Auto-deploy script (VPS)
setup/
  install.ts               # Prerequisites checker + installer
  configure-launchd.ts     # macOS launchd plist generator
  configure-services.ts    # Windows/Linux PM2 + scheduler
  verify.ts                # Full health check
  test-telegram.ts         # Telegram connectivity test
  test-supabase.ts         # Supabase connectivity test
  setup-google-oauth.ts    # Google OAuth token setup (Gmail + Calendar)
  uninstall.ts             # Clean removal (cross-platform)
  upgrade.ts               # Connect ZIP downloads to git repo
launchd/
  templates/               # Plist templates for macOS services
logs/                      # Service log files
docs/
  setup-guide.md           # Full setup walkthrough (Phases 0-10)
  architecture.md          # Architecture deep dive
  troubleshooting.md       # Common issues and fixes
  faq.md                   # Frequently asked questions
```

## Registered Agents

These agents are active in `src/agents/index.ts` and receive messages via Telegram topic routing:

| Agent | Key | Purpose |
|-------|-----|---------|
| General (Orchestrator) | `general` | Default assistant, cross-agent coordination |
| Software Engineering | `software` | Full-stack coding, debugging, DevOps (Systematic reasoning) |
| Database (Supabase) | `database` | Schema, queries, migrations, RLS, performance (CoT) |
| BP Documents | `bp-docs` | Document creation, reports, SOPs (CoT) |
| BP Contracts | `bp-contracts` | MSAs, SOWs, vendor agreements, compliance (CoT) |
| BP Invoices | `bp-invoices` | Invoice review, PO matching, discrepancy tracking (CoT) |
| BP Finance & Budgets | `bp-finance` | Budget tracking, forecasting, cost analysis (CoT) |
| Critic | `critic` | Devil's advocate, stress-testing (internal, not topic-bound) |

Legacy agents (research, content, finance, strategy) and draft agents (coo, cto) exist as files but are **not registered** in the agent index.

## Architecture

### Deployment Modes

| Mode | Entry Point | How It Works |
|------|-------------|-------------|
| **Local** | `bun run start` | Polls Telegram, uses Claude Code CLI subprocess |
| **VPS** | `bun run vps` | Webhook mode, Anthropic API (direct or Agent SDK) |
| **Hybrid** | Both | VPS always on, forwards to local when machine is awake |

### Tiered Model Routing

All processing paths classify message complexity for model selection:

| Tier | Model | When | Response Time |
|------|-------|------|--------------|
| Haiku | claude-haiku-4-5 | Greetings, status checks, short questions | 2-5s |
| Sonnet | claude-sonnet-4-5 | Medium tasks, unclear complexity | 5-15s |
| Opus | claude-opus-4-6 | Research, analysis, strategy, long writing | 15-60s |

- **Local mode:** Routing is UX-only — all use Claude Code subprocess. Sonnet/Opus tier uses streaming (`--output-format stream-json`) for live progress in Telegram.
- **VPS mode:** Routing selects actual model. Haiku uses direct API; Sonnet/Opus use Agent SDK when `USE_AGENT_SDK=true`.
- **Budget:** Daily cost limit via `DAILY_API_BUDGET` (default $5). Auto-downgrades Opus→Sonnet when low.

### MCP Integration

Claude Code subprocesses inherit your MCP configuration. Connect MCP servers in Claude Code settings and the bot automatically has access.

## Key Configuration Files

| File | Purpose | Git |
|------|---------|-----|
| `.env` | All credentials and API keys | gitignored |
| `.mcp.json` | Supabase MCP server config | gitignored |
| `config/profile.md` | User profile for agent context | gitignored |
| `config/schedule.json` | Check-in and briefing schedule | gitignored |
| `src/agents/base.ts` | Topic routing + cross-agent permissions | tracked |
| `src/lib/bot-registry.ts` | Multi-bot agent identity mapping | tracked |
| `db/schema.sql` | Database schema (safe to re-run) | tracked |

## Commands

```bash
# --- Core ---
bun run start              # Local mode (polling, Claude Code CLI)
bun run vps                # VPS mode (webhook, Anthropic API)
bun run checkin            # Run check-in manually
bun run briefing           # Run morning briefing manually
bun run setup:verify       # Full health check

# --- Setup ---
bun run setup              # Prerequisites checker
bun run setup:launchd      # Generate macOS launchd plists
bun run setup:services     # Configure PM2 (Windows/Linux)
bun run setup:google       # Google OAuth setup (Gmail + Calendar)
bun run upgrade            # Connect ZIP download to git repo
bun run uninstall          # Clean removal

# --- Testing ---
bun run test:telegram      # Telegram connectivity test
bun run test:supabase      # Supabase connectivity test

# --- macOS Service Management ---
launchctl list | grep com.go                           # Check status
launchctl unload ~/Library/LaunchAgents/com.go.telegram-relay.plist  # Stop
launchctl load ~/Library/LaunchAgents/com.go.telegram-relay.plist    # Start

# --- VPS (PM2) ---
pm2 status                 # Check status
pm2 restart go-bot         # Restart
pm2 logs go-bot --lines 50 # View logs
```

## Gotchas & Troubleshooting

> See `docs/troubleshooting.md` for the full list.

**Claude subprocess:**
- JSON responses often wrapped in `` ```json `` fences — the bot strips these automatically
- Always kill subprocesses on timeout to avoid zombie processes
- **Never use Claude subprocesses to fetch data (email, calendar, etc.) from background scripts.** Claude initializes all MCP servers on startup (60-180s). Use direct REST APIs instead — see `docs/architecture.md`

**launchd:**
- `StartInterval` pauses during sleep and does NOT catch up
- `StartCalendarInterval` fires immediately after wake if missed
- After editing a plist: unload then load (not just load)

**Supabase:**
- Use `service_role` key (not just `anon`) for write operations
- `db/schema.sql` uses `IF NOT EXISTS` — safe to re-run, never drop existing tables
- NEVER drop or recreate tables to resolve conflicts — existing data will be lost

**Human-in-the-loop:**
- Requires `async_tasks` table in Supabase
- Stale tasks auto-remind after 2 hours

**Environment:**
- Must `unset CLAUDECODE` env var when running bot from within a Claude Code session
- Gemini models: use `gemini-2.5-flash` (`2.0-flash` is deprecated)

<!-- Updated March 3, 2026: Restructured for dev focus. Setup tutorial moved to docs/setup-guide.md. Updated agents and project structure to match current codebase. -->
