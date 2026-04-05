# Mac Studio Setup Guide

> This guide is for after you've run the setup script. If you haven't yet, do this first:
>
> ```bash
> git clone https://github.com/Ancientfall/go-bot.git ~/go-bot
> cd ~/go-bot
> chmod +x setup/mac-studio-setup.sh
> ./setup/mac-studio-setup.sh
> ```

---

## What Was Installed

| Tool | What It Does |
|------|-------------|
| **Homebrew** | App store for developer tools |
| **Git** | Version control (tracks code changes) |
| **Node.js** | JavaScript runtime (needed for Claude Code) |
| **Bun** | Faster JavaScript runtime (runs GoBot) |
| **Python 3** | Programming language for AI/ML |
| **uv** | Modern Python package manager |
| **Ollama** | Runs AI models locally on your Mac |
| **Open WebUI** | ChatGPT-like web interface for local AI |
| **Claude Code** | AI coding assistant in the terminal |
| **VS Code** | Code editor (optional) |
| **iTerm2** | Better terminal app (optional) |
| **Tailscale** | Secure remote access VPN (optional) |

---

## Quick Start: Try Your Local AI

### Option 1: Web Interface (Easiest)

1. Open your web browser (Safari, Chrome, etc.)
2. Go to **http://localhost:8080**
3. Create a local account (this is just for you — nothing goes to the internet)
4. Pick a model from the dropdown (try **llama3.2** for fast responses)
5. Start chatting!

### Option 2: Terminal

1. Open Terminal (or iTerm2)
2. Type: `ollama run llama3.2`
3. Ask it anything — type your question and press Enter
4. Type `/bye` to exit

---

## Your AI Models

These models run **100% on your Mac**. No internet needed. Completely private.

| Model | Best For | Speed |
|-------|----------|-------|
| **llama3.2** | Quick questions, general chat | Very fast |
| **mistral** | Writing, summarization | Fast |
| **qwen3-coder** | Coding help (also GoBot's fallback) | Fast |
| **deepseek-r1:14b** | Complex reasoning, analysis | Medium |

### Adding More Models

Want to try a different model? Just run:
```bash
ollama pull <model-name>
```

Some good ones to try:
- `gemma3` — Google's model, good all-rounder
- `phi4` — Microsoft's small but smart model
- `codellama` — Specialized for coding

Browse all available models at: https://ollama.com/library

---

## Setting Up GoBot

GoBot is your personal AI assistant on Telegram. Setting it up requires a few accounts and API keys. Follow the phases in order.

### Phase 1: Telegram Bot (~5 minutes)

You need a Telegram account and a bot token.

1. Install Telegram on your phone if you don't have it
2. Open Telegram and message **@BotFather**
3. Send `/newbot` and follow the prompts
4. Copy the **bot token** it gives you (looks like `123456789:ABCdef...`)
5. Message **@userinfobot** — it will reply with your **user ID** (a number)
6. Edit your `.env` file:
   ```bash
   cd ~/go-bot
   open .env    # Opens in TextEdit, or use: code .env (for VS Code)
   ```
7. Find these lines and fill them in:
   ```
   TELEGRAM_BOT_TOKEN=paste_your_bot_token_here
   TELEGRAM_USER_ID=paste_your_user_id_here
   ```
8. Save the file

### Phase 2: Supabase Database (~10 minutes)

GoBot needs a database to remember conversations.

1. Go to **https://supabase.com** and create a free account
2. Click **New Project** — pick any name and region
3. Wait ~2 minutes for it to set up
4. Go to **Project Settings > API** and copy:
   - **Project URL** (looks like `https://abc123.supabase.co`)
   - **Publishable key** (may start with `eyJ...` or `sb_publishable_...`)
   - **Secret key** (may start with `eyJ...` or `sb_secret_...`)
5. Edit `.env` and fill in:
   ```
   SUPABASE_URL=paste_your_project_url
   SUPABASE_ANON_KEY=paste_your_publishable_key
   SUPABASE_SERVICE_ROLE_KEY=paste_your_secret_key
   ```
6. Go to the **SQL Editor** in your Supabase dashboard
7. Open the file `~/go-bot/db/schema.sql`, copy its entire contents
8. Paste into the SQL Editor and click **Run**

### Phase 3: Test GoBot

```bash
cd ~/go-bot
bun run test:telegram     # Tests your Telegram connection
bun run test:supabase     # Tests your database connection
bun run start             # Starts GoBot!
```

Send a message to your bot on Telegram — it should respond!

Press **Ctrl+C** to stop the bot.

### Phase 4: Make GoBot Always-On

To keep GoBot running in the background (even after you close Terminal):

```bash
cd ~/go-bot
bun run setup:launchd -- --service all
```

This sets up macOS to automatically run GoBot whenever your Mac is on.

---

## Setting Up Tailscale (Remote Access)

Tailscale lets you access your Mac Studio from anywhere.

1. Open Tailscale from your Applications folder
2. Click **Log In** and create an account
3. On your other devices, install Tailscale and log in with the same account
4. Your devices can now connect to each other securely

---

## Managing Services

### Ollama (Local AI)
```bash
# Check if running
brew services list | grep ollama

# Restart
brew services restart ollama

# Stop
brew services stop ollama
```

### Open WebUI
```bash
# Check if running
curl -s http://localhost:8080 > /dev/null && echo "Running" || echo "Not running"

# Restart
launchctl unload ~/Library/LaunchAgents/com.openwebui.server.plist
launchctl load ~/Library/LaunchAgents/com.openwebui.server.plist

# View logs
cat ~/Library/Logs/open-webui.log
```

### GoBot
```bash
# Check status
launchctl list | grep com.go

# View logs
ls ~/go-bot/logs/
```

---

## Troubleshooting

### "command not found" errors
Close Terminal and open a new one. New tools need a fresh Terminal session.

### Open WebUI won't load
1. Check Ollama is running: `brew services list | grep ollama`
2. Restart it: `brew services restart ollama`
3. Wait 10 seconds, then try http://localhost:8080 again

### GoBot won't respond on Telegram
1. Check your `.env` file has the correct bot token and user ID
2. Run `bun run test:telegram` to test the connection
3. Make sure only one instance of the bot is running

### AI models are slow
- Close other memory-heavy apps (browsers with many tabs, etc.)
- Try a smaller model: `ollama run llama3.2` (2GB) instead of `deepseek-r1:14b` (9GB)
- Check Activity Monitor > Memory to see what's using RAM

### Need to re-run setup
The setup script is safe to run again:
```bash
cd ~/go-bot
./setup/mac-studio-setup.sh
```
It will skip everything that's already installed.

---

## Updating

### Update GoBot
```bash
cd ~/go-bot
git pull
bun install
```

### Update Ollama models
```bash
ollama pull llama3.2      # Re-downloads if newer version available
ollama pull mistral
```

### Update all Homebrew tools
```bash
brew update && brew upgrade
```

### Update Open WebUI
```bash
uv tool upgrade open-webui
```
