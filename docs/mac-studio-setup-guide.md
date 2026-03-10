# Mac Studio Setup Guide for Andrew

**What this does:** Sets up your Mac Studio as a local AI powerhouse with GoBot, local LLMs, remote access, and all the development tools you need.

**Time required:** ~30-60 minutes (mostly waiting for downloads)

---

## Quick Start

Open **Terminal** (press `Cmd + Space`, type "Terminal", press Enter) and run:

```bash
cd ~/go-bot
./setup/mac-studio-setup.sh
```

The script is interactive — it will ask you before making major changes and explain everything along the way.

---

## What Gets Installed

### Development Tools
| Tool | What It Does |
|------|-------------|
| **Homebrew** | macOS package manager (like an app store for terminal tools) |
| **Bun** | Fast TypeScript runtime that GoBot runs on |
| **Node.js** | JavaScript runtime (needed for some tools) |
| **Python 3** | For ML/AI tools and scripts |
| **Git** | Version control |
| **Claude Code CLI** | Anthropic's AI coding assistant in the terminal |

### Local LLM Software
| Tool | What It Does |
|------|-------------|
| **Ollama** | Runs AI models locally on your Mac — no internet needed |
| **LM Studio** | Beautiful GUI app for downloading and chatting with local models |

### AI Models (via Ollama)

The script picks the best models based on your Mac Studio's RAM:

| Your RAM | Models Installed | Best For |
|----------|-----------------|----------|
| **192 GB** | llama3.3:70b, qwen3:72b, deepseek-r1:70b, qwen3:32b, llama3.2:3b | Full-size models, maximum quality |
| **96 GB** | qwen3:32b, llama3.3:70b, deepseek-r1:32b, llama3.2:3b | Large models with good headroom |
| **64 GB** | qwen3:32b, deepseek-r1:32b, llama3.1:8b, llama3.2:3b | Mid-size models, great balance |
| **32 GB** | llama3.1:8b, qwen3:8b, deepseek-r1:8b, llama3.2:3b | Smaller but capable models |

**Model Highlights:**
- **qwen3** — Excellent for coding tasks, fast responses
- **llama3.3** — Meta's best open model, great all-rounder
- **deepseek-r1** — Specializes in reasoning and complex problem solving
- **llama3.2:3b** — Ultra-fast for quick questions (2-3 second responses)
- **nomic-embed-text** — Creates embeddings for semantic search (used by GoBot)

### Productivity Apps
| App | What It Does |
|-----|-------------|
| **iTerm2** | Better terminal than the built-in one (tabs, split panes, search) |
| **VS Code** | Code editor with great extensions |
| **Stats** | Shows CPU/GPU/RAM usage in the menu bar — great for monitoring LLM inference |
| **Raycast** | Spotlight replacement with productivity features |

---

## Remote Access Setup

The script configures three ways to access your Mac Studio remotely:

### 1. SSH (Command Line Access)
Connect from any other computer's terminal:
```bash
# From your local network
ssh andrew@192.168.x.x

# From anywhere (via Tailscale)
ssh andrew@100.x.x.x
```

### 2. Screen Sharing (Full Desktop Access)
See and control the Mac Studio's desktop:
- **From a Mac:** Finder → Go → Connect to Server → `vnc://192.168.x.x`
- **From Windows/Linux:** Use any VNC client (RealVNC, TightVNC)
- **From iPad/iPhone:** Use the "Screens" app or Apple's built-in Screen Sharing

### 3. Tailscale (Access from Anywhere)
Tailscale creates a secure private network between all your devices:

1. **On the Mac Studio:** Open the Tailscale app → Sign in with Google/GitHub/etc.
2. **On your laptop/phone:** Install Tailscale → Sign in with the same account
3. **Done!** Both devices get a `100.x.x.x` address that works from anywhere

**Why Tailscale?**
- No port forwarding needed on your router
- No dynamic DNS to configure
- Encrypted end-to-end
- Works through firewalls and NATs
- Free for personal use (up to 100 devices)

After Tailscale is set up, you can SSH/VNC into your Mac Studio from a coffee shop, office, or anywhere with internet.

---

## After the Script Runs

### Step 1: Set Up Tailscale
1. Click the Tailscale icon in your menu bar (or open the app)
2. Sign in with your preferred account
3. Install Tailscale on your other devices (laptop, phone)
4. Note your Mac Studio's Tailscale IP (starts with `100.`)

### Step 2: Configure GoBot
Edit the environment file with your API keys:
```bash
nano ~/go-bot/.env
```

**Required keys to fill in:**

| Key | Where to Get It |
|-----|----------------|
| `TELEGRAM_BOT_TOKEN` | Message [@BotFather](https://t.me/botfather) on Telegram → `/newbot` |
| `TELEGRAM_USER_ID` | Message [@userinfobot](https://t.me/userinfobot) on Telegram |
| `ANTHROPIC_API_KEY` | [console.anthropic.com](https://console.anthropic.com) → API Keys |
| `SUPABASE_URL` | [supabase.com](https://supabase.com) → Your Project → Settings → API |
| `SUPABASE_ANON_KEY` | Same place as SUPABASE_URL |
| `USER_NAME` | Your name (e.g., "Andrew") |
| `BOT_NAME` | What to call the bot (e.g., "Go") |

### Step 3: Verify Everything Works
```bash
cd ~/go-bot
bun run setup:verify
```

This checks all connections and reports any issues.

### Step 4: Start the Bot
```bash
cd ~/go-bot
bun run start
```

### Step 5: Make It Always-On
To have GoBot start automatically and survive reboots:
```bash
cd ~/go-bot
bun run setup:launchd
```

This creates macOS services that keep the bot running 24/7.

---

## Using Local LLMs

### Ollama (Command Line)

```bash
# Chat with a model
ollama run qwen3:32b

# Ask a one-off question
ollama run llama3.2:3b "What is the capital of France?"

# List installed models
ollama list

# Pull a new model
ollama pull mistral

# Check Ollama is running
curl http://localhost:11434/api/tags | jq
```

### LM Studio (GUI)

1. Open LM Studio from Applications
2. Browse and download models from HuggingFace
3. Load a model and start chatting
4. Can also run as a local API server (OpenAI-compatible)

### GoBot Integration

GoBot automatically uses Ollama as a fallback when Claude is unavailable. The model is configured in `~/go-bot/.env`:

```env
OLLAMA_MODEL=qwen3:32b        # Which model to use
FALLBACK_OFFLINE_ONLY=false    # Set true to always use local only
```

---

## Power & Performance Settings

The script configures your Mac Studio for 24/7 operation:

| Setting | Value | Why |
|---------|-------|-----|
| System sleep | Disabled | Keeps Mac available for remote access |
| Disk sleep | Disabled | Prevents delays when accessing files |
| Wake on LAN | Enabled | Can wake the Mac remotely |
| Auto-restart after power failure | Enabled | Recovers from outages automatically |
| High performance mode | Enabled | Maximum speed for LLM inference |

---

## Monitoring & Maintenance

### Check System Resources
The **Stats** app in the menu bar shows real-time CPU, GPU, RAM, and network usage. This is especially useful when running large LLMs to see memory pressure.

### Check Ollama Status
```bash
# See running models
ollama ps

# See all models and their sizes
ollama list

# Check API is responding
curl -s http://localhost:11434/api/tags | jq '.models[].name'
```

### Check GoBot Status
```bash
# If running via launchd
launchctl list | grep com.go

# View bot logs
tail -f ~/go-bot/logs/telegram-relay.log

# Full health check
cd ~/go-bot && bun run setup:verify
```

### Update Models
```bash
# Update a specific model to latest version
ollama pull qwen3:32b

# Remove a model you no longer need
ollama rm <model-name>
```

---

## Troubleshooting

### "Permission denied" when running the script
```bash
chmod +x ~/go-bot/setup/mac-studio-setup.sh
./setup/mac-studio-setup.sh
```

### Ollama won't start
```bash
# Check if it's running
pgrep ollama

# Restart via Homebrew
brew services restart ollama

# Or start manually
ollama serve
```

### Can't connect via SSH
1. Check SSH is enabled: System Settings → General → Sharing → Remote Login
2. Check your IP: `ipconfig getifaddr en0`
3. Make sure both devices are on the same network (or use Tailscale)

### Can't connect via Tailscale
1. Make sure Tailscale is running on both devices
2. Both devices must be signed into the same Tailscale account
3. Check your Tailscale IP: `tailscale ip -4`

### Models are slow
- Check RAM usage with **Stats** app — if near 100%, try a smaller model
- Close other heavy applications
- Run `ollama ps` to see if multiple models are loaded

### GoBot won't start
```bash
cd ~/go-bot
bun run setup:verify    # Check what's wrong
bun install             # Reinstall dependencies
bun run start           # Try again
```

---

## Recommended Model Sizes by Task

| Task | Recommended Model | Speed |
|------|------------------|-------|
| Quick questions | llama3.2:3b | 2-3 seconds |
| Code generation | qwen3:32b | 5-15 seconds |
| Deep reasoning | deepseek-r1:70b | 15-60 seconds |
| General chat | llama3.3:70b | 10-30 seconds |
| Embeddings/search | nomic-embed-text | <1 second |

---

## Need Help?

- **GoBot docs:** `~/go-bot/docs/setup-guide.md`
- **GoBot troubleshooting:** `~/go-bot/docs/troubleshooting.md`
- **Ollama docs:** https://ollama.ai
- **Tailscale docs:** https://tailscale.com/kb
