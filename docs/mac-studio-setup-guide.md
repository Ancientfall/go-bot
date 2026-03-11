# Mac Studio Setup Guide for Andrew

**What this does:** Sets up your Mac Studio as a local AI powerhouse with GoBot, local LLMs, remote access, and all the development tools you need.

**Time required:** ~30-60 minutes (mostly waiting for downloads)

---

## Before You Begin — Get GoBot onto the Mac Studio

GoBot isn't available to download publicly — you'll need to copy it from your laptop first. Pick whichever method is easiest:

### Option A: AirDrop (Easiest)
1. On your **laptop**, right-click the `~/go-bot` folder → **Compress "go-bot"**
2. AirDrop the `.zip` file to the Mac Studio
3. On the Mac Studio, double-click the `.zip` to unzip it
4. Move the folder to your home directory: drag it to `~/go-bot` (or open Terminal and run `mv ~/Downloads/go-bot ~/go-bot`)

### Option B: Copy Over the Network
Both machines need to be on the same Wi-Fi. On your **laptop**, run:
```bash
scp -r ~/go-bot andrew@<mac-studio-ip>:~/go-bot
```
*(Replace `<mac-studio-ip>` with the Mac Studio's IP address — find it in System Settings → Wi-Fi → Details → IP Address)*

### Option C: USB Drive
1. Copy the `~/go-bot` folder onto a USB drive
2. Plug the USB into the Mac Studio
3. Copy the folder to `~/go-bot`

---

## Quick Start

Once GoBot is at `~/go-bot`, open **Terminal** (press `Cmd + Space`, type "Terminal", press Enter) and run:

```bash
cd ~/go-bot
chmod +x setup/mac-studio-setup.sh
./setup/mac-studio-setup.sh
```

The script is interactive — it will ask you before making major changes and explain everything along the way. It will also configure GoBot to pull future updates from GitHub automatically.

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
| **GitHub CLI (gh)** | Manage repos, PRs, and issues from the terminal |
| **Claude Code CLI** | Anthropic's AI coding assistant in the terminal |
| **ffmpeg** | Audio/video processing (powers GoBot's voice features) |
| **jq** | JSON processing for configs and API responses |
| **htop** | Interactive process monitor |
| **wget** | File downloader |
| **tree** | Visualize directory structures |

### Local LLM Software
| Tool | What It Does |
|------|-------------|
| **Ollama** | Runs AI models locally on your Mac — no internet needed, API at `localhost:11434` |
| **LM Studio** | Beautiful GUI app for downloading and chatting with local models |
| **Open WebUI** | ChatGPT-like web interface for all your Ollama models at `localhost:3080` |

### AI Models (via Ollama)

**Every install includes `qwen3-coder`** — this is GoBot's default fallback model, optimized for coding tasks. Additional models are selected based on your RAM:

| Your RAM | Models Installed | Best For |
|----------|-----------------|----------|
| **192 GB** | qwen3-coder, llama3.3:70b, qwen3:72b, deepseek-r1:70b, qwen3:32b, gemma3:27b, mistral-small, llama3.2:3b | Full-size models, maximum quality |
| **96 GB** | qwen3-coder, llama3.3:70b, qwen3:32b, deepseek-r1:32b, gemma3:27b, llama3.2:3b | Large models with good headroom |
| **64 GB** | qwen3-coder, qwen3:32b, deepseek-r1:32b, gemma3:12b, llama3.1:8b, llama3.2:3b | Mid-size models, great balance |
| **32 GB** | qwen3-coder, llama3.1:8b, qwen3:8b, deepseek-r1:8b, gemma3:4b, llama3.2:3b | Smaller but capable models |

**Model Highlights:**
- **qwen3-coder** — GoBot's default fallback. Coding-optimized, fast responses
- **llama3.3** — Meta's best open model, great all-rounder
- **deepseek-r1** — Chain-of-thought reasoning specialist (like o1/o3)
- **gemma3** — Google's latest open model, strong at reasoning and instruction following
- **mistral-small** — Mistral's efficient model, excellent instruction following
- **llama3.2:3b** — Ultra-fast for quick questions (2-3 second responses)
- **nomic-embed-text** — Local embeddings for semantic search / RAG

### Productivity & Communication Apps
| App | What It Does |
|-----|-------------|
| **Telegram Desktop** | Required for interacting with GoBot |
| **iTerm2** | Better terminal (tabs, split panes, search, profiles) |
| **VS Code** | Code editor with great extensions |
| **Docker Desktop** | Run containers (needed for Open WebUI and other services) |
| **Notion** | Project management (integrates with GoBot morning briefings) |
| **Raycast** | Spotlight replacement with clipboard history, snippets, AI |
| **Rectangle** | Window snapping with keyboard shortcuts (Ctrl+Opt+Arrow) |
| **AltTab** | Windows-style Alt+Tab window switcher with previews |
| **Stats** | CPU/GPU/RAM/network monitor in menu bar |
| **The Unarchiver** | Open any compressed file format |
| **AppCleaner** | Cleanly remove apps and their leftover files |

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

After Tailscale is set up, you can SSH/VNC into your Mac Studio from a coffee shop, office, or anywhere with internet. You can also access Open WebUI at `http://100.x.x.x:3080` from anywhere.

---

## After the Script Runs

### Step 1: Set Up Tailscale
1. Click the Tailscale icon in your menu bar (or open the app)
2. Sign in with your preferred account
3. Install Tailscale on your other devices (laptop, phone)
4. Note your Mac Studio's Tailscale IP (starts with `100.`)

### Step 2: Open WebUI Setup
1. Visit `http://localhost:3080` in your browser
2. Create an admin account (first user becomes admin)
3. All your Ollama models are automatically available
4. You can access this from any device on your network or via Tailscale

### Step 3: Configure GoBot
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

### Step 4: Verify Everything Works
```bash
cd ~/go-bot
bun run setup:verify
```

This checks all connections and reports any issues.

### Step 5: Start the Bot
```bash
cd ~/go-bot
bun run start
```

### Step 6: Make It Always-On
To have GoBot start automatically and survive reboots:
```bash
cd ~/go-bot
bun run setup:launchd
```

This creates macOS services that keep the bot running 24/7.

---

## Using Local LLMs

### Open WebUI (Easiest Way)
Visit `http://localhost:3080` — it's like ChatGPT but runs entirely on your Mac:
- Chat with any installed Ollama model
- Switch models mid-conversation
- Upload documents for analysis
- Create custom presets and system prompts
- Access from any device on your network
- Access remotely via Tailscale at `http://100.x.x.x:3080`

### Ollama (Command Line)

```bash
# Chat with GoBot's default model
ollama run qwen3-coder

# Quick chat with the fast small model
ollama run llama3.2:3b

# Ask a one-off question
ollama run llama3.2:3b "What is the capital of France?"

# Chat with the best reasoning model
ollama run deepseek-r1:32b

# List installed models
ollama list

# See currently loaded/running models
ollama ps

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

GoBot automatically uses Ollama as a fallback when Claude is unavailable. The default model is `qwen3-coder` (set in `src/lib/fallback-llm.ts`). Override in `~/go-bot/.env`:

```env
OLLAMA_MODEL=qwen3-coder       # GoBot's default fallback model
FALLBACK_OFFLINE_ONLY=false     # Set true to skip cloud, use local only
```

**Fallback chain:** Claude Code CLI → OpenRouter (cloud) → Ollama (local) → error message

---

## macOS Settings Applied

### Power & Performance (Always-On Server)
| Setting | Value | Why |
|---------|-------|-----|
| System sleep | Disabled | Keeps Mac available for remote access + LLM serving |
| Disk sleep | Disabled | Prevents delays when accessing files |
| Display sleep | 10 minutes | Mac Studio is typically headless |
| Wake on LAN | Enabled | Can wake the Mac remotely |
| Auto-restart after power failure | Enabled | Recovers from outages automatically |
| High performance mode | Enabled | Maximum speed for LLM inference |
| Spotlight indexing | Disabled for model dirs | Saves CPU, prevents indexing GB of model files |

### Productivity Settings
| Setting | What Changed | Why |
|---------|-------------|-----|
| Dock | Auto-hide enabled | More screen space |
| Dock | Recent apps hidden | Cleaner dock |
| Finder | List view default | More productive file browsing |
| Finder | Path bar + status bar shown | See where you are |
| Finder | Hidden files visible | See dotfiles (.env, .git, etc.) |
| Finder | Folders sorted first | Easier navigation |
| .DS_Store | Disabled on network/USB | No junk files on shared drives |
| Keyboard | Fast key repeat (2/15) | Essential for terminal/coding |
| Keyboard | Auto-correct disabled | Prevents mangling code/commands |
| Keyboard | Smart quotes/dashes disabled | Prevents breaking code when pasting |
| Keyboard | Full keyboard access | Tab through all UI controls |
| Screenshots | Save to ~/Screenshots | Keep desktop clean |
| Screenshots | PNG format, no shadow | Clean captures |
| Security | Firewall enabled | Blocks unwanted connections |
| Security | Stealth mode on | Don't respond to network probes |
| Security | Lock screen immediate | Require password after lock |
| Safari | Developer menu enabled | Web development tools |

---

## Keyboard Shortcuts Cheat Sheet

| Shortcut | App | Action |
|----------|-----|--------|
| `Ctrl+Opt+Left/Right` | Rectangle | Snap window to left/right half |
| `Ctrl+Opt+Up/Down` | Rectangle | Snap to top/bottom half |
| `Ctrl+Opt+Enter` | Rectangle | Maximize window |
| `Cmd+Space` | Raycast | Open launcher (Spotlight replacement) |
| `Cmd+\`` | macOS | Switch windows within same app |
---

## Monitoring & Maintenance

### Check System Resources
The **Stats** app in the menu bar shows real-time CPU, GPU, RAM, and network usage. This is especially useful when running large LLMs to see memory pressure.

### Check Ollama Status
```bash
# See running models and their memory usage
ollama ps

# See all installed models and their sizes
ollama list

# Check API is responding
curl -s http://localhost:11434/api/tags | jq '.models[].name'
```

### Check Open WebUI
```bash
# See if the container is running
docker ps | grep open-webui

# Restart if needed
docker restart open-webui

# View logs
docker logs open-webui --tail 50
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
ollama pull qwen3-coder

# Remove a model you no longer need
ollama rm <model-name>

# Update Open WebUI
docker pull ghcr.io/open-webui/open-webui:main
docker restart open-webui
```

---

## Recommended Model Sizes by Task

| Task | Recommended Model | Speed | Notes |
|------|------------------|-------|-------|
| GoBot fallback | qwen3-coder | 3-8 sec | Auto-used when Claude is down |
| Quick questions | llama3.2:3b | 2-3 sec | Ultra-fast, good for simple tasks |
| Code generation | qwen3:32b | 5-15 sec | Excellent code quality |
| Deep reasoning | deepseek-r1:70b | 15-60 sec | Chain-of-thought, shows work |
| General chat | llama3.3:70b | 10-30 sec | Best all-around open model |
| Google-quality | gemma3:27b | 8-20 sec | Strong reasoning, efficient |
| Embeddings/search | nomic-embed-text | <1 sec | For semantic search / RAG |

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

### Open WebUI won't load
```bash
# Make sure Docker is running (open Docker Desktop)
docker ps

# Restart the container
docker restart open-webui

# Check logs for errors
docker logs open-webui --tail 20
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
- Run `ollama ps` to see if multiple models are loaded (each uses RAM)
- Unload unused models: restart Ollama with `brew services restart ollama`

### GoBot won't start
```bash
cd ~/go-bot
bun run setup:verify    # Check what's wrong
bun install             # Reinstall dependencies
bun run start           # Try again
```

---

## Need Help?

- **GoBot docs:** `~/go-bot/docs/setup-guide.md`
- **GoBot troubleshooting:** `~/go-bot/docs/troubleshooting.md`
- **Ollama docs:** https://ollama.ai
- **Open WebUI docs:** https://docs.openwebui.com
- **Tailscale docs:** https://tailscale.com/kb
- **Rectangle shortcuts:** https://rectangleapp.com
