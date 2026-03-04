# GoBot Setup Guide

> This guide walks through setting up GoBot from scratch using Claude Code.
> Each phase is designed to be completed through conversation with Claude Code.

## Prerequisites

Before starting, ensure you have:
- [ ] **macOS, Windows, or Linux**
- [ ] **Bun** runtime installed (`curl -fsSL https://bun.sh/install | bash`)
  - **Important:** After installing Bun, restart your terminal or add Bun to your PATH:
    ```bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    ```
  - To make this permanent, add those two lines to your `~/.zshrc` (macOS) or `~/.bashrc` (Linux)
- [ ] **Claude Code** CLI installed and authenticated (`claude --version`)
- [ ] A **Telegram** account
- [ ] **Windows/Linux only**: PM2 for daemon services (`npm install -g pm2`)

## What to Expect During Setup

Claude Code will ask for permission before running commands or editing files. When you see a permission prompt:
- **"Allow tool access"** — Select "Allow for this session" or "Always allow" to let Claude Code run setup commands
- **macOS "Background Items" popup** — When launchd services start, macOS may show a notification saying *"Software from 'Jared Sumner' can run in the background"*. This is normal — Jared Sumner is the creator of the Bun runtime. Click **Allow** to let the bot services run.

---

## Phase 0: Environment Scan (Automatic, ~1 min)

> **Claude Code: Run this BEFORE starting Phase 1. Always. Even if the user says they're starting fresh.**

### What Claude Code does:

**Step 1 — Ask the user:**

"Have you previously set up a Telegram bot with Claude Code, or any similar AI assistant project? For example, the free mini-course relay, or your own custom setup?"

**Step 2 — Scan regardless of answer:**

Even if the user says "no," run these checks silently. They may have forgotten, or someone else set it up on their machine.

1. **Check if this is a ZIP download (no git):**
   - Check if `.git/` directory exists in the project root
   - If NO `.git/`: this is a ZIP download. Tell the user:
     "This looks like a ZIP download. Run `bun run upgrade` to connect to the official repo — this lets you pull future updates with `git pull` without losing your config."
   - If `.git/` exists: check `git remote get-url origin` — verify it points to `autonomee/gobot`
   - If wrong remote: suggest `bun run upgrade` to fix it

2. **Check for existing `.env` file** in this project directory. If it exists, read it and catalog every variable that has a real value (not a placeholder like `your_bot_token_here`).

3. **Check for other bot projects** on the machine:
   - Look for `~/.claude-relay/` directory (free mini-course relay)
   - Look for `~/claude-telegram-relay/` or any folder matching `*telegram*relay*` in `~/`, `~/Desktop/`, `~/Downloads/`, `~/Documents/`, `~/development/`
   - If found, read their `.env` files for reusable credentials

4. **Check for running services:**
   - macOS: `launchctl list | grep -E "com\.go\.|claude.*relay|telegram"`
   - Linux/Windows: `pm2 list` (if pm2 exists)
   - Report any existing bot services that might conflict

5. **Check for existing Supabase MCP:**
   - Look for `supabase` in Claude Code's MCP configuration
   - If connected, test the connection

6. **Check for existing Supabase tables** (if credentials found):
   - Run `bun run setup/test-supabase.ts` to verify connectivity
   - Query for existing tables: `messages`, `memory`, `logs`, `async_tasks`, `node_heartbeat`, `call_transcripts`
   - Check if data exists in `messages` table (indicates active prior usage)

7. **Check for existing profile:**
   - Look for `config/profile.md` in this project
   - Look for `~/.claude-relay/profile.md` or similar in discovered projects

**Step 3 — Report findings:**

Present a clear summary to the user:

```
ENVIRONMENT SCAN RESULTS

Git connection: ✅ Connected to autonomee/gobot / ⚠️ ZIP download (run: bun run upgrade)
Existing setup found: Yes/No
Source: [this project / claude-telegram-relay at ~/path / other]

✅ Telegram Bot Token — found, valid
✅ Telegram User ID — found
✅ Supabase URL — found
✅ Supabase Anon Key — found
❌ Supabase Service Role Key — missing (needed for GoBot)
✅ User Name — "Sarah"
✅ User Timezone — "Europe/Berlin"
✅ Profile — found at [path]
❌ Anthropic API Key — not set (needed for VPS mode)
❌ Voice/ElevenLabs — not configured
❌ Fallback LLMs — not configured

Supabase tables:
✅ messages (1,247 rows — your history is preserved)
✅ memory (23 rows)
✅ logs (456 rows)
❌ async_tasks — missing (new in GoBot)
❌ node_heartbeat — missing (new in GoBot)

Running services:
⚠️ claude-relay daemon running (will conflict — needs stopping)

RECOMMENDATION:
I can carry over your Telegram, Supabase, and profile settings.
I'll add the missing tables without touching your existing data.
Phases 1-3 can be skipped. Starting at Phase 4 (Agents).
Stop the old relay service first? [Yes/No]
```

**Step 4 — Act on findings:**

- **Reusable credentials found:** Copy them into this project's `.env`. Confirm with the user before overwriting anything. Never delete the source.
- **Existing Supabase with data:** Run `db/schema.sql` which uses `IF NOT EXISTS` — safe for existing tables. Only new tables get created.
- **Conflicting services found:** Ask the user before stopping them. Explain that two bots polling the same Telegram token will cause message conflicts.
- **Profile found:** Offer to copy it to `config/profile.md`. Let user review it first.
- **Nothing found:** Proceed normally from Phase 1. No special handling needed.

**Step 5 — Skip completed phases:**

Based on the scan, tell the user which phases are already done and which remain. Jump directly to the first incomplete phase.

---

## Phase 1: Telegram Bot (Required, ~5 min)

### What you need to do:
1. Open Telegram and message [@BotFather](https://t.me/BotFather)
2. Send `/newbot` and follow the prompts to create your bot
3. Copy the bot token (looks like `123456789:ABCdefGhIjKlMnOpQrStUvWxYz`)
4. Get your Telegram user ID:
   - Click this exact link: **[@userinfobot](https://t.me/userinfobot)** (make sure it says "userinfobot", not "usinfobot" or similar)
   - Send it any message (like "hi") — it immediately replies with your numeric user ID
   - Your user ID is a number like `123456789` (this is NOT your username)
   - **Warning:** There are copycat bots with similar names (like "@usinfobot"). Make sure you open the link above — the correct bot replies instantly with your ID, no menus or buttons

### What Claude Code does:
- Creates `.env` from `.env.example` if it doesn't exist
- Saves your `TELEGRAM_BOT_TOKEN` and `TELEGRAM_USER_ID` to `.env`
- Runs `bun run setup/test-telegram.ts` to verify connectivity

### Tell me:
"Here's my bot token: [TOKEN] and my user ID: [ID]"

---

## Phase 2: Supabase (Required, ~10 min)

### What you need to do:
1. Go to [supabase.com](https://supabase.com) and create a free account
2. Create a new project (any name, choose a region close to you)
3. Wait for the project to finish setting up (~2 min)
4. Go to Project Settings > API and copy:
   - **Project URL** (looks like `https://abc123.supabase.co`)
   - **Publishable key** (labeled "anon public" or "Publishable" — may start with `eyJ...` or `sb_publishable_...`)
   - **Secret key** (labeled "service_role" or "Secret" — may start with `eyJ...` or `sb_secret_...` — keep this secret!)

### What Claude Code does:
- Saves your Supabase credentials to `.env`
- Opens `db/schema.sql` and runs it in your Supabase SQL editor (you paste it)
- Runs `bun run setup/test-supabase.ts` to verify connectivity

> **WARNING — Existing Supabase data:** If you're using an existing Supabase project that already has data, **do NOT drop or delete any existing tables**. The schema uses `CREATE TABLE IF NOT EXISTS` which safely skips tables that already exist. If Claude Code suggests dropping, restructuring, or recreating tables to resolve a conflict, **say no** — your existing data will be permanently deleted. Instead, create a new separate Supabase project for the bot, or manually add only the missing tables.

> **Upgrading from a previous version?** Just re-run `db/schema.sql` — all statements use `IF NOT EXISTS` and are safe to re-run. New tables (like `assets`) will be created without touching existing data. After running the schema, create a Storage bucket named `gobot-assets` in your Supabase Dashboard (Settings > Storage > New Bucket > Name: "gobot-assets" > Make public).

### Tell me:
"Here are my Supabase keys: URL=[URL], anon=[KEY], service_role=[KEY]"

> **Note:** Supabase recently renamed their keys. "anon public key" is now called "Publishable key" and may start with `sb_publishable_` instead of `eyJ`. Both formats work — just paste whatever your dashboard shows.

---

## Phase 2.5: Semantic Search (Optional, ~5 min)

Enable AI-powered memory search. Without this, the bot still works — it just uses basic text matching instead of understanding meaning.

### What you need:
1. An OpenAI API key from [platform.openai.com](https://platform.openai.com)
2. Supabase MCP already connected (from Phase 2)

### What Claude Code does:
- Stores your OpenAI key as a Supabase secret
- Deploys two edge functions (store-telegram-message, search-memory)
- Runs the match_messages SQL function in your database
- Verifies semantic search works

### Tell me:
"Set up semantic search. My OpenAI key is [your key]" or "Skip" to use basic text search.

---

## Phase 3: Personalization (Required, ~5 min)

### What Claude Code does:
- Asks you questions about yourself (name, timezone, profession, constraints)
- Creates `config/profile.md` with your answers
- Sets `USER_TIMEZONE` in `.env`

### Tell me:
Answer the questions I'll ask about your name, timezone, and work style.

---

## Phase 4: Agent Customization (Optional, ~10 min)

The bot includes pre-configured agents. You can customize them or use defaults.

### To use forum topics (multi-agent routing):
1. Create a Telegram group with forum/topics enabled
2. Add your bot as admin
3. Create topics matching your agents
4. Send a message in each topic -- check logs for the topic ID numbers
5. Tell me the topic IDs and I'll update `src/agents/base.ts`

### Multi-Bot Agent Identities (Optional)

Each agent can have its own Telegram bot, so messages appear from separate identities instead of all coming from the main bot.

**Without multi-bot:** Everything works fine — all agents respond through your main bot.
**With multi-bot:** Each agent sends messages from its own bot account for visual separation.

#### Setup steps:
1. Open [@BotFather](https://t.me/BotFather) on Telegram
2. Create agent bots with `/newbot`
3. Copy each bot token and add to `.env` with the pattern `TELEGRAM_BOT_TOKEN_<AGENT>=token_here`
4. You don't need to set up webhooks — agent bots are outbound-only (send messages, no polling).

Any tokens you skip will gracefully fall back to the main bot.

### Cross-Agent Consultation

When enabled (via multi-bot tokens), agents can consult each other during conversations. This happens automatically through `[INVOKE:agent|question]` tags in the agent's thinking.

### Board Meetings (`/board`)

The `/board` command triggers a multi-agent discussion. All configured agents weigh in on a topic sequentially, then a synthesis is generated. Works with or without multi-bot tokens.

### Tell me:
"Use defaults" or "I want to customize agents" or provide your topic IDs. For multi-bot, share the tokens you created.

---

## Phase 5: Test Core Bot (Required, ~2 min)

### What Claude Code does:
- Runs `bun run start` to start the bot manually
- Tells you to send a test message on Telegram
- Verifies the bot responds
- Ctrl+C to stop

### Tell me:
"Start the test" and then confirm if you got a response on Telegram.

---

## Phase 6: Scheduled Services (Optional, ~10 min)

### Smart Check-ins
Proactive messages based on your goals, schedule, and conversation history.

### Morning Briefing
Daily summary with goals and context from your configured data sources.

### What Claude Code does:
- Asks your preferred check-in schedule (or uses defaults from `config/schedule.example.json`)
- Creates `config/schedule.json`
- Generates launchd plist files

### Tell me:
"Set up check-ins and briefings" or "Skip for now"

---

## Phase 6.5: Data Sources (Optional, ~5 min)

Morning briefings pull live data from connected services. Each source auto-enables when its env vars are set — no config files needed.

### Available Sources

| Source | Env Vars Needed | What It Shows |
|--------|----------------|---------------|
| **Goals** | _(always on)_ | Active goals from Supabase/local |
| **Ops Briefing** | _(always on)_ | Operations-specific briefing data |
| **AI News** | `XAI_API_KEY` or `GEMINI_API_KEY` | Top AI news via xAI Grok or Gemini |
| **Gmail** | `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN` | Unread email count + top subjects |
| **Calendar** | _(same Google OAuth)_ | Today's events with times |
| **Notion Tasks** | `NOTION_TOKEN`, `NOTION_DATABASE_ID` | Due and overdue tasks |

### Google OAuth Setup (Gmail + Calendar)
```bash
bun run setup:google
```

### Custom Sources
```bash
cp src/lib/data-sources/sources/custom.example.ts src/lib/data-sources/sources/my-source.ts
```
Then import it in `src/lib/data-sources/sources/index.ts`.

Data sources use direct REST APIs — no MCP servers needed. They work on VPS, local, and hybrid mode equally.

### Tell me:
"Set up data sources" or list which ones you want, or "Skip"

---

## Phase 7: Always-On (Required after Phase 5, ~5 min)

### What Claude Code does:
- **macOS**: Runs `bun run setup:launchd -- --service all` to generate and load launchd services
- **Windows/Linux**: Runs `bun run setup:services -- --service all` to configure PM2 + scheduler
- Verifies services are running
- Explains how to check logs and restart services

### Tell me:
"Make it always-on"

---

## Phase 8: Optional Integrations (~5 min each)

### Voice Replies (Gemini / ElevenLabs)
- Text-to-speech for voice message responses
- Requires: Gemini API key or ElevenLabs API key + voice ID

### Phone Calls (ElevenLabs + Twilio)
- AI can call you for urgent check-ins
- Requires: ElevenLabs agent + Twilio phone number

### Audio Transcription (Gemini)
- Transcribe voice messages before sending to Claude
- Requires: Google Gemini API key

### Fallback LLM (OpenRouter / Ollama)
- Backup responses when Claude is unavailable
- OpenRouter: cloud fallback (API key)
- Ollama: local fallback (install + run)

### Tell me:
"Set up [integration name]" with your API keys, or "Skip integrations"

---

## Phase 9: VPS Deployment (Optional, ~30 min)

Deploy the bot to a cloud VPS so it runs 24/7 without depending on your local machine.

| Mode | How It Works | Cost |
|------|-------------|------|
| **Local Only** | Runs on your machine using Claude Code CLI | Claude Pro ($20/mo) or Max ($100-200/mo) |
| **VPS** (recommended for 24/7) | Same code on VPS, Claude Code CLI + API key | VPS (~$5/mo) + API costs |
| **Hybrid** | VPS always on, forwards to local when awake | VPS + API costs + subscription |

### How VPS Works

**Claude Code CLI works with an `ANTHROPIC_API_KEY` environment variable.** When set, it uses the Anthropic API (pay-per-token). You still get ALL Claude Code features (MCP servers, skills, hooks, CLAUDE.md, built-in tools).

Clone the repo on VPS, install Claude Code, set your API key, and run `bun run start`. Same experience as local.

### What you need:
1. **A VPS** — Any provider works
2. **Anthropic API key** — From [console.anthropic.com](https://console.anthropic.com)
3. **Claude Code CLI** — Installed on your VPS (`npm install -g @anthropic-ai/claude-code`)

### Tell me:
"Deploy to VPS" and I'll walk you through it.

---

## Phase 10: Verification (Required, ~2 min)

### What Claude Code does:
- Runs `bun run setup:verify` for full health check
- Tests all configured services
- Reports pass/fail for each component

### Tell me:
"Run verification"
