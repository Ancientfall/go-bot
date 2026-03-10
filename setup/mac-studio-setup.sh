#!/usr/bin/env bash
#
# mac-studio-setup.sh — Complete Mac Studio Setup for Andrew
#
# This script sets up a Mac Studio as a local LLM powerhouse + GoBot server
# with remote access, development tools, and everything needed to run
# local AI models at full speed.
#
# Usage:
#   curl -fsSL <raw-github-url> | bash
#   — or —
#   chmod +x setup/mac-studio-setup.sh && ./setup/mac-studio-setup.sh
#
# What this script does:
#   1. Installs Xcode Command Line Tools
#   2. Installs Homebrew
#   3. Installs core dev tools (git, bun, node, python, gh, ffmpeg)
#   4. Installs Claude Code CLI
#   5. Installs & configures Ollama for local LLMs
#   6. Pulls GoBot-optimized models (qwen3-coder + RAM-appropriate selection)
#   7. Installs LM Studio (GUI for local models)
#   8. Enables macOS Remote Access (SSH + Screen Sharing)
#   9. Installs Tailscale VPN (remote access from anywhere)
#  10. Installs productivity apps (Docker, Open WebUI, Telegram, VS Code,
#      iTerm2, Rectangle, Stats, Raycast, Arc, Notion, 1Password, etc.)
#  11. Configures macOS for always-on server mode (power, performance,
#      Dock, Finder, keyboard, screenshots, security, firewall)
#  12. Clones and sets up GoBot with Ollama fallback pre-configured
#
# Tested on: macOS Ventura 14+, Apple Silicon (M1/M2/M4 Ultra)
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colors & helpers ────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✘${NC}  $*"; }
header()  { echo -e "\n${BOLD}${CYAN}━━━ $* ━━━${NC}\n"; }
step()    { echo -e "${BOLD}→${NC} $*"; }

# Track what was installed for the summary
INSTALLED_ITEMS=()
SKIPPED_ITEMS=()
MANUAL_STEPS=()

add_installed() { INSTALLED_ITEMS+=("$1"); }
add_skipped()   { SKIPPED_ITEMS+=("$1"); }
add_manual()    { MANUAL_STEPS+=("$1"); }

# ── Pre-flight checks ──────────────────────────────────────────────
header "Pre-flight Checks"

if [[ "$(uname)" != "Darwin" ]]; then
    error "This script is for macOS only. Detected: $(uname)"
    exit 1
fi

ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
    warn "This script is optimized for Apple Silicon (arm64). Detected: $ARCH"
    warn "Some LLM features may not work optimally on Intel Macs."
fi

# Detect Mac model and RAM
MAC_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | grep "Model Name" | awk -F': ' '{print $2}' || echo "Unknown Mac")
RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
RAM_GB=$((RAM_BYTES / 1073741824))

info "Machine:  $MAC_MODEL"
info "Chip:     $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
info "RAM:      ${RAM_GB} GB"
info "Arch:     $ARCH"
info "macOS:    $(sw_vers -productVersion)"

if [[ $RAM_GB -lt 16 ]]; then
    warn "Less than 16 GB RAM detected. Large LLMs may not fit in memory."
    warn "Recommended: 64 GB+ for running 70B+ models."
fi

echo ""
echo -e "${BOLD}This script will install development tools, LLM software,${NC}"
echo -e "${BOLD}and configure your Mac Studio for remote access + GoBot.${NC}"
echo ""
read -rp "Press Enter to continue (or Ctrl+C to abort)... "

# ── 1. Xcode Command Line Tools ────────────────────────────────────
header "Step 1/11: Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
    success "Xcode Command Line Tools already installed"
    add_skipped "Xcode CLI Tools (already installed)"
else
    step "Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    # Wait for the install to complete
    echo "   A dialog box should appear. Click 'Install' and wait for it to finish."
    echo "   Press Enter here once the installation is complete."
    read -rp "   Press Enter to continue..."
    if xcode-select -p &>/dev/null; then
        success "Xcode Command Line Tools installed"
        add_installed "Xcode CLI Tools"
    else
        error "Xcode CLI Tools installation may have failed. Continuing anyway..."
    fi
fi

# ── 2. Homebrew ─────────────────────────────────────────────────────
header "Step 2/11: Homebrew Package Manager"

if command -v brew &>/dev/null; then
    success "Homebrew already installed at $(which brew)"
    step "Updating Homebrew..."
    brew update --quiet
    add_skipped "Homebrew (already installed)"
else
    step "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    # Add to shell profile permanently
    SHELL_PROFILE=""
    if [[ -f "$HOME/.zshrc" ]]; then
        SHELL_PROFILE="$HOME/.zshrc"
    elif [[ -f "$HOME/.bash_profile" ]]; then
        SHELL_PROFILE="$HOME/.bash_profile"
    else
        SHELL_PROFILE="$HOME/.zshrc"
        touch "$SHELL_PROFILE"
    fi

    if ! grep -q 'brew shellenv' "$SHELL_PROFILE" 2>/dev/null; then
        echo '' >> "$SHELL_PROFILE"
        echo '# Homebrew' >> "$SHELL_PROFILE"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_PROFILE"
    fi

    success "Homebrew installed"
    add_installed "Homebrew"
fi

# ── 3. Core Development Tools ──────────────────────────────────────
header "Step 3/11: Core Development Tools"

# Git
if command -v git &>/dev/null; then
    success "Git already installed: $(git --version)"
    add_skipped "Git"
else
    step "Installing Git..."
    brew install git
    success "Git installed"
    add_installed "Git"
fi

# Bun (required for GoBot)
if command -v bun &>/dev/null; then
    success "Bun already installed: $(bun --version)"
    add_skipped "Bun"
else
    step "Installing Bun (TypeScript runtime for GoBot)..."
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    success "Bun installed: $(bun --version)"
    add_installed "Bun"
fi

# Node.js (useful for various tools)
if command -v node &>/dev/null; then
    success "Node.js already installed: $(node --version)"
    add_skipped "Node.js"
else
    step "Installing Node.js..."
    brew install node
    success "Node.js installed: $(node --version)"
    add_installed "Node.js"
fi

# Python 3 (useful for ML/AI tools)
if command -v python3 &>/dev/null; then
    success "Python 3 already installed: $(python3 --version)"
    add_skipped "Python 3"
else
    step "Installing Python 3..."
    brew install python@3
    success "Python 3 installed"
    add_installed "Python 3"
fi

# jq (JSON processing — useful for configs)
if command -v jq &>/dev/null; then
    success "jq already installed"
    add_skipped "jq"
else
    step "Installing jq..."
    brew install jq
    success "jq installed"
    add_installed "jq"
fi

# htop (process monitoring)
if command -v htop &>/dev/null; then
    success "htop already installed"
    add_skipped "htop"
else
    step "Installing htop..."
    brew install htop
    success "htop installed"
    add_installed "htop"
fi

# wget (file downloader — useful for fetching models, configs)
if command -v wget &>/dev/null; then
    success "wget already installed"
    add_skipped "wget"
else
    step "Installing wget..."
    brew install wget
    success "wget installed"
    add_installed "wget"
fi

# tree (directory visualization)
if command -v tree &>/dev/null; then
    success "tree already installed"
    add_skipped "tree"
else
    step "Installing tree..."
    brew install tree
    success "tree installed"
    add_installed "tree"
fi

# gh (GitHub CLI — manage repos, PRs, issues from terminal)
if command -v gh &>/dev/null; then
    success "GitHub CLI already installed"
    add_skipped "GitHub CLI (gh)"
else
    step "Installing GitHub CLI..."
    brew install gh
    success "GitHub CLI installed"
    add_installed "GitHub CLI (gh)"
fi

# ffmpeg (media processing — useful for voice/transcription features)
if command -v ffmpeg &>/dev/null; then
    success "ffmpeg already installed"
    add_skipped "ffmpeg"
else
    step "Installing ffmpeg (audio/video processing for voice features)..."
    brew install ffmpeg
    success "ffmpeg installed"
    add_installed "ffmpeg"
fi

# ── 4. Claude Code CLI ─────────────────────────────────────────────
header "Step 4/11: Claude Code CLI"

if command -v claude &>/dev/null; then
    success "Claude Code CLI already installed"
    add_skipped "Claude Code CLI"
else
    step "Installing Claude Code CLI..."
    if command -v npm &>/dev/null; then
        npm install -g @anthropic-ai/claude-code
        success "Claude Code CLI installed"
        add_installed "Claude Code CLI"
    else
        warn "npm not available. Install Claude Code CLI manually:"
        warn "  npm install -g @anthropic-ai/claude-code"
        add_manual "Install Claude Code CLI: npm install -g @anthropic-ai/claude-code"
    fi
fi

# ── 5. Ollama — Local LLM Engine ───────────────────────────────────
header "Step 5/11: Ollama (Local LLM Engine)"

if command -v ollama &>/dev/null; then
    success "Ollama already installed: $(ollama --version 2>/dev/null || echo 'version unknown')"
    add_skipped "Ollama"
else
    step "Installing Ollama..."
    brew install ollama
    success "Ollama installed"
    add_installed "Ollama"
fi

# Start Ollama service
step "Ensuring Ollama is running..."
if pgrep -x "ollama" &>/dev/null || curl -sf http://localhost:11434/api/tags &>/dev/null; then
    success "Ollama is already running"
else
    step "Starting Ollama service..."
    brew services start ollama 2>/dev/null || ollama serve &>/dev/null &
    sleep 3
    if curl -sf http://localhost:11434/api/tags &>/dev/null; then
        success "Ollama started successfully"
    else
        warn "Ollama may still be starting up. Give it a moment."
    fi
fi

# Pull recommended models based on available RAM
header "Step 5b: Pulling Recommended LLM Models"

echo ""
echo "Based on your ${RAM_GB} GB RAM, here are the recommended models:"
echo ""

# GoBot uses "qwen3-coder" as its default Ollama fallback model (see src/lib/fallback-llm.ts).
# We always install qwen3-coder plus the best general/reasoning models for the available RAM.
MODELS_TO_PULL=()

# Model roles explained:
#   qwen3-coder   — GoBot's DEFAULT fallback model (coding-optimized, fast)
#   llama3.3      — Best open general-purpose model from Meta
#   deepseek-r1   — Chain-of-thought reasoning specialist
#   qwen3         — Alibaba's flagship (excellent at coding + multilingual)
#   llama3.2:3b   — Ultra-fast for quick responses (2-3 sec)
#   nomic-embed-text — Local embeddings for semantic search / RAG

echo -e "  ${CYAN}[GoBot Default]${NC}"
echo -e "  ${GREEN}●${NC} qwen3-coder           — GoBot's fallback model (coding-optimized)"
echo ""
echo -e "  ${CYAN}[Based on ${RAM_GB} GB RAM]${NC}"

if [[ $RAM_GB -ge 192 ]]; then
    echo -e "  ${GREEN}●${NC} llama3.3:70b          — Meta's best open model (70B, full quality)"
    echo -e "  ${GREEN}●${NC} qwen3:72b             — Alibaba's top model (72B, great for coding)"
    echo -e "  ${GREEN}●${NC} deepseek-r1:70b       — DeepSeek reasoning model (70B)"
    echo -e "  ${GREEN}●${NC} qwen3:32b             — Fast mid-size coding model (32B)"
    echo -e "  ${GREEN}●${NC} gemma3:27b            — Google's latest open model (27B, strong reasoning)"
    echo -e "  ${GREEN}●${NC} mistral-small         — Mistral's efficient model (great instruction following)"
    echo -e "  ${GREEN}●${NC} llama3.2:3b           — Ultra-fast for quick tasks (3B)"
    echo -e "  ${GREEN}●${NC} nomic-embed-text      — Local embeddings for semantic search"
    MODELS_TO_PULL=("qwen3-coder" "llama3.3:70b" "qwen3:72b" "deepseek-r1:70b" "qwen3:32b" "gemma3:27b" "mistral-small" "llama3.2:3b" "nomic-embed-text")
elif [[ $RAM_GB -ge 96 ]]; then
    echo -e "  ${GREEN}●${NC} llama3.3:70b          — Meta's best (70B — fits with headroom)"
    echo -e "  ${GREEN}●${NC} qwen3:32b             — Great coding model (32B)"
    echo -e "  ${GREEN}●${NC} deepseek-r1:32b       — Reasoning model (32B)"
    echo -e "  ${GREEN}●${NC} gemma3:27b            — Google's latest open model (27B)"
    echo -e "  ${GREEN}●${NC} llama3.2:3b           — Ultra-fast for quick tasks (3B)"
    echo -e "  ${GREEN}●${NC} nomic-embed-text      — Local embeddings for semantic search"
    MODELS_TO_PULL=("qwen3-coder" "llama3.3:70b" "qwen3:32b" "deepseek-r1:32b" "gemma3:27b" "llama3.2:3b" "nomic-embed-text")
elif [[ $RAM_GB -ge 64 ]]; then
    echo -e "  ${GREEN}●${NC} qwen3:32b             — Great coding model (32B)"
    echo -e "  ${GREEN}●${NC} deepseek-r1:32b       — Reasoning model (32B)"
    echo -e "  ${GREEN}●${NC} gemma3:12b            — Google's efficient model (12B)"
    echo -e "  ${GREEN}●${NC} llama3.1:8b           — Solid general model (8B)"
    echo -e "  ${GREEN}●${NC} llama3.2:3b           — Ultra-fast small model (3B)"
    echo -e "  ${GREEN}●${NC} nomic-embed-text      — Local embeddings for semantic search"
    MODELS_TO_PULL=("qwen3-coder" "qwen3:32b" "deepseek-r1:32b" "gemma3:12b" "llama3.1:8b" "llama3.2:3b" "nomic-embed-text")
elif [[ $RAM_GB -ge 32 ]]; then
    echo -e "  ${GREEN}●${NC} llama3.1:8b           — Solid general model (8B)"
    echo -e "  ${GREEN}●${NC} qwen3:8b              — Good coding model (8B)"
    echo -e "  ${GREEN}●${NC} deepseek-r1:8b        — Reasoning model (8B)"
    echo -e "  ${GREEN}●${NC} gemma3:4b             — Google's small model (4B)"
    echo -e "  ${GREEN}●${NC} llama3.2:3b           — Ultra-fast small model (3B)"
    echo -e "  ${GREEN}●${NC} nomic-embed-text      — Local embeddings for semantic search"
    MODELS_TO_PULL=("qwen3-coder" "llama3.1:8b" "qwen3:8b" "deepseek-r1:8b" "gemma3:4b" "llama3.2:3b" "nomic-embed-text")
else
    echo -e "  ${GREEN}●${NC} llama3.2:3b           — Fast small model (3B)"
    echo -e "  ${GREEN}●${NC} gemma3:4b             — Google's small model (4B)"
    echo -e "  ${GREEN}●${NC} nomic-embed-text      — Local embeddings for semantic search"
    MODELS_TO_PULL=("qwen3-coder" "llama3.2:3b" "gemma3:4b" "nomic-embed-text")
fi

echo ""
read -rp "Pull these models now? This may take a while depending on your connection. [Y/n] " PULL_MODELS
PULL_MODELS=${PULL_MODELS:-Y}

if [[ "$PULL_MODELS" =~ ^[Yy]$ ]]; then
    for model in "${MODELS_TO_PULL[@]}"; do
        step "Pulling $model ..."
        if ollama pull "$model" 2>&1; then
            success "Pulled $model"
            add_installed "Ollama model: $model"
        else
            warn "Failed to pull $model — you can pull it later with: ollama pull $model"
        fi
    done
else
    info "Skipping model pulls. You can pull models later with:"
    for model in "${MODELS_TO_PULL[@]}"; do
        echo "    ollama pull $model"
    done
    add_manual "Pull Ollama models (see commands above)"
fi

# ── 6. LM Studio (GUI for Local LLMs) ──────────────────────────────
header "Step 6/11: LM Studio (GUI for Local Models)"

if [[ -d "/Applications/LM Studio.app" ]]; then
    success "LM Studio already installed"
    add_skipped "LM Studio"
else
    step "Installing LM Studio..."
    brew install --cask lm-studio 2>/dev/null && {
        success "LM Studio installed"
        add_installed "LM Studio"
    } || {
        warn "Could not install LM Studio via Homebrew."
        warn "Download manually from: https://lmstudio.ai"
        add_manual "Install LM Studio from https://lmstudio.ai"
    }
fi

# ── 7. Remote Access — SSH & Screen Sharing ─────────────────────────
header "Step 7/11: Remote Access (SSH + Screen Sharing)"

# Enable SSH (Remote Login)
step "Checking Remote Login (SSH)..."
SSH_STATUS=$(sudo systemsetup -getremotelogin 2>/dev/null | awk '{print $NF}' || echo "Unknown")
if [[ "$SSH_STATUS" == "On" ]]; then
    success "Remote Login (SSH) is already enabled"
    add_skipped "SSH Remote Login"
else
    echo ""
    echo "   Remote Login (SSH) lets you connect to this Mac from another computer"
    echo "   using: ssh andrew@<ip-address>"
    echo ""
    read -rp "   Enable SSH Remote Login? [Y/n] " ENABLE_SSH
    ENABLE_SSH=${ENABLE_SSH:-Y}
    if [[ "$ENABLE_SSH" =~ ^[Yy]$ ]]; then
        sudo systemsetup -setremotelogin on 2>/dev/null && {
            success "SSH Remote Login enabled"
            add_installed "SSH Remote Login"
        } || {
            warn "Could not enable SSH via command line."
            add_manual "Enable SSH: System Settings → General → Sharing → Remote Login → ON"
        }
    else
        add_manual "Enable SSH: System Settings → General → Sharing → Remote Login → ON"
    fi
fi

# Enable Screen Sharing (VNC)
step "Checking Screen Sharing..."
SCREEN_SHARING=$(sudo launchctl list 2>/dev/null | grep -c "com.apple.screensharing" || echo "0")
if [[ "$SCREEN_SHARING" -gt 0 ]]; then
    success "Screen Sharing appears to be enabled"
    add_skipped "Screen Sharing"
else
    echo ""
    echo "   Screen Sharing lets you see and control this Mac's desktop remotely."
    echo "   On another Mac, use Finder → Go → Connect to Server → vnc://<ip>"
    echo ""
    read -rp "   Enable Screen Sharing? [Y/n] " ENABLE_VNC
    ENABLE_VNC=${ENABLE_VNC:-Y}
    if [[ "$ENABLE_VNC" =~ ^[Yy]$ ]]; then
        # Try enabling via command line
        sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null && {
            success "Screen Sharing enabled"
            add_installed "Screen Sharing (VNC)"
        } || {
            warn "Could not enable Screen Sharing via command line."
            add_manual "Enable Screen Sharing: System Settings → General → Sharing → Screen Sharing → ON"
        }
    else
        add_manual "Enable Screen Sharing: System Settings → General → Sharing → Screen Sharing → ON"
    fi
fi

# Show local IP
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "Unknown")
info "Local IP address: $LOCAL_IP"
info "SSH access:  ssh $(whoami)@$LOCAL_IP"
info "VNC access:  vnc://$LOCAL_IP"

# ── 8. Tailscale VPN (Remote Access from Anywhere) ─────────────────
header "Step 8/11: Tailscale VPN (Secure Remote Access from Anywhere)"

echo ""
echo "   Tailscale creates a secure private network between your devices."
echo "   Once set up, you can SSH/VNC into this Mac Studio from anywhere"
echo "   in the world — no port forwarding or dynamic DNS needed."
echo ""

if command -v tailscale &>/dev/null || [[ -d "/Applications/Tailscale.app" ]]; then
    success "Tailscale already installed"
    add_skipped "Tailscale"

    # Check if connected
    TAILSCALE_STATUS=$(tailscale status 2>/dev/null | head -1 || echo "unknown")
    if echo "$TAILSCALE_STATUS" | grep -qi "stopped\|logged out"; then
        add_manual "Connect Tailscale: Open Tailscale app and sign in"
    else
        success "Tailscale appears to be connected"
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
        if [[ "$TAILSCALE_IP" != "unknown" ]]; then
            info "Tailscale IP: $TAILSCALE_IP"
            info "Remote SSH:   ssh $(whoami)@$TAILSCALE_IP"
            info "Remote VNC:   vnc://$TAILSCALE_IP"
        fi
    fi
else
    read -rp "   Install Tailscale? [Y/n] " INSTALL_TAILSCALE
    INSTALL_TAILSCALE=${INSTALL_TAILSCALE:-Y}
    if [[ "$INSTALL_TAILSCALE" =~ ^[Yy]$ ]]; then
        brew install --cask tailscale 2>/dev/null && {
            success "Tailscale installed"
            add_installed "Tailscale"
            add_manual "Open Tailscale app, sign in, and approve this device"
            add_manual "Install Tailscale on your other devices too for remote access"
        } || {
            warn "Could not install Tailscale via Homebrew."
            add_manual "Install Tailscale from: https://tailscale.com/download/mac"
        }
    else
        add_manual "Install Tailscale from: https://tailscale.com/download/mac"
    fi
fi

# ── 9. Useful Mac Applications ──────────────────────────────────────
header "Step 9/11: Recommended Applications"

echo ""
echo -e "   ${BOLD}Development Tools${NC}"
echo ""

# iTerm2
if [[ -d "/Applications/iTerm.app" ]]; then
    success "iTerm2 already installed"
    add_skipped "iTerm2"
else
    step "Installing iTerm2 (better terminal with tabs, split panes, search)..."
    brew install --cask iterm2 2>/dev/null && {
        success "iTerm2 installed"
        add_installed "iTerm2"
    } || add_manual "Install iTerm2 from https://iterm2.com"
fi

# VS Code
if [[ -d "/Applications/Visual Studio Code.app" ]] || command -v code &>/dev/null; then
    success "VS Code already installed"
    add_skipped "VS Code"
else
    step "Installing Visual Studio Code..."
    brew install --cask visual-studio-code 2>/dev/null && {
        success "VS Code installed"
        add_installed "VS Code"
    } || add_manual "Install VS Code from https://code.visualstudio.com"
fi

# Docker Desktop (containers — useful for dev and self-hosted services)
if [[ -d "/Applications/Docker.app" ]] || command -v docker &>/dev/null; then
    success "Docker already installed"
    add_skipped "Docker"
else
    step "Installing Docker Desktop (containers for dev & self-hosted services)..."
    brew install --cask docker 2>/dev/null && {
        success "Docker Desktop installed"
        add_installed "Docker Desktop"
    } || add_manual "Install Docker Desktop from https://docker.com/products/docker-desktop"
fi

echo ""
echo -e "   ${BOLD}AI & LLM Tools${NC}"
echo ""

# Open WebUI (beautiful web chat interface for Ollama — like ChatGPT but local)
step "Checking for Open WebUI (ChatGPT-like interface for local models)..."
if command -v docker &>/dev/null || [[ -d "/Applications/Docker.app" ]]; then
    WEBUI_RUNNING=$(docker ps 2>/dev/null | grep -c "open-webui" || echo "0")
    if [[ "$WEBUI_RUNNING" -gt 0 ]]; then
        success "Open WebUI already running"
        add_skipped "Open WebUI"
    else
        echo ""
        echo "   Open WebUI gives you a ChatGPT-like web interface for all your local models."
        echo "   Access it at http://localhost:3080 from any device on your network."
        echo ""
        read -rp "   Install Open WebUI? (requires Docker) [Y/n] " INSTALL_WEBUI
        INSTALL_WEBUI=${INSTALL_WEBUI:-Y}
        if [[ "$INSTALL_WEBUI" =~ ^[Yy]$ ]]; then
            docker run -d --name open-webui \
                -p 3080:8080 \
                --add-host=host.docker.internal:host-gateway \
                -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
                -v open-webui:/app/backend/data \
                --restart always \
                ghcr.io/open-webui/open-webui:main 2>/dev/null && {
                success "Open WebUI installed — access at http://localhost:3080"
                add_installed "Open WebUI (http://localhost:3080)"
            } || {
                warn "Docker may need to be started first. Open Docker Desktop, then retry."
                add_manual "Start Docker Desktop, then run: docker run -d --name open-webui -p 3080:8080 --add-host=host.docker.internal:host-gateway -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -v open-webui:/app/backend/data --restart always ghcr.io/open-webui/open-webui:main"
            }
        fi
    fi
else
    info "Open WebUI requires Docker. Install Docker first, then run the setup again."
    add_manual "After Docker is installed: docker run -d --name open-webui -p 3080:8080 --add-host=host.docker.internal:host-gateway -e OLLAMA_BASE_URL=http://host.docker.internal:11434 -v open-webui:/app/backend/data --restart always ghcr.io/open-webui/open-webui:main"
fi

echo ""
echo -e "   ${BOLD}System Monitoring & Productivity${NC}"
echo ""

# Stats (system monitor in menu bar)
if [[ -d "/Applications/Stats.app" ]]; then
    success "Stats already installed"
    add_skipped "Stats"
else
    step "Installing Stats (CPU/GPU/RAM/network monitor in menu bar)..."
    brew install --cask stats 2>/dev/null && {
        success "Stats installed — essential for monitoring during LLM inference"
        add_installed "Stats (system monitor)"
    } || add_manual "Install Stats from https://github.com/exelban/stats"
fi

# Raycast (Spotlight replacement)
if [[ -d "/Applications/Raycast.app" ]]; then
    success "Raycast already installed"
    add_skipped "Raycast"
else
    step "Installing Raycast (Spotlight replacement with clipboard history, snippets, AI)..."
    brew install --cask raycast 2>/dev/null && {
        success "Raycast installed"
        add_installed "Raycast"
    } || add_skipped "Raycast (install failed)"
fi

# Rectangle (window management — snap windows with keyboard shortcuts)
if [[ -d "/Applications/Rectangle.app" ]]; then
    success "Rectangle already installed"
    add_skipped "Rectangle"
else
    step "Installing Rectangle (window snapping with keyboard shortcuts)..."
    brew install --cask rectangle 2>/dev/null && {
        success "Rectangle installed — use Ctrl+Option+Arrow keys to snap windows"
        add_installed "Rectangle (window manager)"
    } || add_skipped "Rectangle (install failed)"
fi

# Alt-Tab (Windows-style Alt+Tab window switcher with previews)
if [[ -d "/Applications/AltTab.app" ]]; then
    success "AltTab already installed"
    add_skipped "AltTab"
else
    step "Installing AltTab (Windows-style window switcher with previews)..."
    brew install --cask alt-tab 2>/dev/null && {
        success "AltTab installed"
        add_installed "AltTab"
    } || add_skipped "AltTab (install failed)"
fi

echo ""
echo -e "   ${BOLD}Communication & Browsing${NC}"
echo ""

# Telegram Desktop (required for interacting with GoBot)
if [[ -d "/Applications/Telegram.app" ]] || [[ -d "/Applications/Telegram Desktop.app" ]]; then
    success "Telegram already installed"
    add_skipped "Telegram Desktop"
else
    step "Installing Telegram Desktop (needed for GoBot interaction)..."
    brew install --cask telegram 2>/dev/null && {
        success "Telegram Desktop installed"
        add_installed "Telegram Desktop"
    } || add_manual "Install Telegram Desktop from https://desktop.telegram.org"
fi

# Notion (project management — integrates with GoBot briefings)
if [[ -d "/Applications/Notion.app" ]]; then
    success "Notion already installed"
    add_skipped "Notion"
else
    step "Installing Notion (integrates with GoBot morning briefings)..."
    brew install --cask notion 2>/dev/null && {
        success "Notion installed"
        add_installed "Notion"
    } || add_skipped "Notion (install failed, optional)"
fi

echo ""
echo -e "   ${BOLD}Utilities${NC}"
echo ""

# The Unarchiver (handle any compressed file format)
if [[ -d "/Applications/The Unarchiver.app" ]]; then
    success "The Unarchiver already installed"
    add_skipped "The Unarchiver"
else
    step "Installing The Unarchiver (open any archive format)..."
    brew install --cask the-unarchiver 2>/dev/null && {
        success "The Unarchiver installed"
        add_installed "The Unarchiver"
    } || add_skipped "The Unarchiver (install failed, optional)"
fi

# AppCleaner (clean uninstall of apps)
if [[ -d "/Applications/AppCleaner.app" ]]; then
    success "AppCleaner already installed"
    add_skipped "AppCleaner"
else
    step "Installing AppCleaner (cleanly uninstall apps and their leftovers)..."
    brew install --cask appcleaner 2>/dev/null && {
        success "AppCleaner installed"
        add_installed "AppCleaner"
    } || add_skipped "AppCleaner (install failed, optional)"
fi

# ── 10. macOS Performance & Power Settings ──────────────────────────
header "Step 10/11: macOS Performance & Power Settings"

echo ""
echo -e "   ${BOLD}Power Management (Always-On Server Mode)${NC}"
echo ""

# Prevent sleep when display is off (important for remote access + LLM serving)
step "Preventing system sleep (keeps Mac available for remote access & LLM serving)..."
sudo pmset -a sleep 0 2>/dev/null && success "System sleep disabled" || warn "Could not disable system sleep"
sudo pmset -a disksleep 0 2>/dev/null && success "Disk sleep disabled" || warn "Could not disable disk sleep"

# Disable display sleep for desktop (Mac Studio has no display to sleep)
# Only 10 minutes for display sleep since Mac Studio is typically headless
sudo pmset -a displaysleep 10 2>/dev/null && success "Display sleep set to 10 min" || true

# Wake on network access (Wake on LAN)
sudo pmset -a womp 1 2>/dev/null && success "Wake on LAN enabled" || true

# Restart after power failure
sudo pmset -a autorestart 1 2>/dev/null && success "Auto-restart after power failure enabled" || true

# Set high performance mode if available (Mac Studio with M1/M2/M4 Ultra)
sudo pmset -a highpowermode 1 2>/dev/null && success "High Performance mode enabled" || info "High Performance mode not available on this Mac"

echo ""
echo -e "   ${BOLD}Performance Optimizations${NC}"
echo ""

# Reduce motion/transparency for better system performance
defaults write com.apple.universalaccess reduceMotion -bool true 2>/dev/null && info "Reduced motion enabled (saves GPU cycles for LLMs)" || true
defaults write com.apple.universalaccess reduceTransparency -bool true 2>/dev/null && info "Reduced transparency enabled" || true

# Disable Spotlight indexing for common LLM model directories (saves CPU)
step "Excluding model directories from Spotlight indexing..."
OLLAMA_MODELS_DIR="$HOME/.ollama/models"
if [[ -d "$OLLAMA_MODELS_DIR" ]]; then
    sudo mdutil -i off "$OLLAMA_MODELS_DIR" 2>/dev/null && info "Spotlight disabled for Ollama models dir" || true
fi
# Also exclude common LM Studio model path
LMSTUDIO_MODELS_DIR="$HOME/.cache/lm-studio"
if [[ -d "$LMSTUDIO_MODELS_DIR" ]]; then
    sudo mdutil -i off "$LMSTUDIO_MODELS_DIR" 2>/dev/null && info "Spotlight disabled for LM Studio models dir" || true
fi

echo ""
echo -e "   ${BOLD}Finder & File Management${NC}"
echo ""

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true 2>/dev/null && info "Show all file extensions" || true

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true 2>/dev/null && info "Show hidden files in Finder" || true

# Show path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true 2>/dev/null && info "Show path bar in Finder" || true

# Show status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true 2>/dev/null && info "Show status bar in Finder" || true

# Default to list view in Finder (more productive)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv" 2>/dev/null && info "Default to list view in Finder" || true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true 2>/dev/null && info "Folders sorted first in Finder" || true

# Disable the warning when changing file extensions
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false 2>/dev/null || true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true 2>/dev/null && info "Disabled .DS_Store on network volumes" || true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true 2>/dev/null && info "Disabled .DS_Store on USB volumes" || true

echo ""
echo -e "   ${BOLD}Dock & Desktop${NC}"
echo ""

# Auto-hide the Dock (more screen space, especially useful with remote access)
defaults write com.apple.dock autohide -bool true 2>/dev/null && info "Dock auto-hide enabled (more screen space)" || true

# Make Dock auto-hide animation faster
defaults write com.apple.dock autohide-delay -float 0 2>/dev/null || true
defaults write com.apple.dock autohide-time-modifier -float 0.3 2>/dev/null || true

# Minimize windows to their application icon
defaults write com.apple.dock minimize-to-application -bool true 2>/dev/null || true

# Don't show recent applications in Dock
defaults write com.apple.dock show-recents -bool false 2>/dev/null && info "Hidden recent apps from Dock" || true

echo ""
echo -e "   ${BOLD}Keyboard & Input${NC}"
echo ""

# Faster key repeat rate (essential for terminal/coding productivity)
defaults write NSGlobalDomain KeyRepeat -int 2 2>/dev/null && info "Fast key repeat rate" || true
defaults write NSGlobalDomain InitialKeyRepeat -int 15 2>/dev/null && info "Short key repeat delay" || true

# Disable auto-correct (annoying for coding/terminal)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false 2>/dev/null && info "Auto-correct disabled" || true

# Disable smart quotes and dashes (break code when pasting)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false 2>/dev/null && info "Smart quotes disabled" || true
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false 2>/dev/null && info "Smart dashes disabled" || true

# Enable full keyboard access for all controls (Tab through dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3 2>/dev/null && info "Full keyboard access enabled" || true

echo ""
echo -e "   ${BOLD}Screenshots${NC}"
echo ""

# Save screenshots to ~/Screenshots instead of Desktop
SCREENSHOTS_DIR="$HOME/Screenshots"
mkdir -p "$SCREENSHOTS_DIR"
defaults write com.apple.screencapture location -string "$SCREENSHOTS_DIR" 2>/dev/null && info "Screenshots save to ~/Screenshots" || true

# Save screenshots as PNG (lossless)
defaults write com.apple.screencapture type -string "png" 2>/dev/null || true

# Disable screenshot shadow
defaults write com.apple.screencapture disable-shadow -bool true 2>/dev/null && info "Screenshot shadow disabled" || true

echo ""
echo -e "   ${BOLD}Security${NC}"
echo ""

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null && info "Firewall enabled" || true

# Enable stealth mode (don't respond to pings from unknown sources)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null && info "Stealth mode enabled" || true

# Require password immediately after sleep/screensaver
defaults write com.apple.screensaver askForPassword -int 1 2>/dev/null || true
defaults write com.apple.screensaver askForPasswordDelay -int 0 2>/dev/null && info "Password required immediately after lock" || true

echo ""
echo -e "   ${BOLD}Safari & Web (if using Safari)${NC}"
echo ""

# Show full URL in Safari address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true 2>/dev/null || true

# Enable Safari develop menu
defaults write com.apple.Safari IncludeDevelopMenu -bool true 2>/dev/null && info "Safari Developer menu enabled" || true

# Apply Finder & Dock changes
step "Applying Dock and Finder changes..."
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
success "Dock and Finder refreshed"

add_installed "macOS performance tuning + productivity settings"

# ── 11. GoBot Setup ─────────────────────────────────────────────────
header "Step 11/11: GoBot Setup"

GOBOT_DIR="$HOME/go-bot"

if [[ -d "$GOBOT_DIR" ]]; then
    success "GoBot directory already exists at $GOBOT_DIR"
    cd "$GOBOT_DIR"
    step "Pulling latest changes..."
    git pull origin master 2>/dev/null || git pull 2>/dev/null || warn "Could not pull latest changes"
else
    step "Cloning GoBot repository..."
    git clone https://github.com/autonomee/gobot.git "$GOBOT_DIR" 2>/dev/null && {
        success "GoBot cloned to $GOBOT_DIR"
        cd "$GOBOT_DIR"
    } || {
        warn "Could not clone GoBot. You may need to set up GitHub access first."
        add_manual "Clone GoBot: git clone https://github.com/autonomee/gobot.git ~/go-bot"
    }
fi

if [[ -d "$GOBOT_DIR" ]]; then
    cd "$GOBOT_DIR"

    # Install dependencies
    step "Installing GoBot dependencies..."
    if command -v bun &>/dev/null; then
        bun install 2>/dev/null && success "Dependencies installed" || warn "bun install had issues"
    fi

    # Create .env from example if it doesn't exist
    if [[ ! -f "$GOBOT_DIR/.env" ]] && [[ -f "$GOBOT_DIR/.env.example" ]]; then
        cp "$GOBOT_DIR/.env.example" "$GOBOT_DIR/.env"
        success "Created .env from template"
        add_manual "Edit ~/go-bot/.env with your API keys and tokens (see setup guide)"
    fi

    # Create config files from examples if they don't exist
    if [[ ! -f "$GOBOT_DIR/config/profile.md" ]] && [[ -f "$GOBOT_DIR/config/profile.example.md" ]]; then
        cp "$GOBOT_DIR/config/profile.example.md" "$GOBOT_DIR/config/profile.md"
        add_manual "Edit ~/go-bot/config/profile.md with Andrew's personal details"
    fi

    if [[ ! -f "$GOBOT_DIR/config/schedule.json" ]] && [[ -f "$GOBOT_DIR/config/schedule.example.json" ]]; then
        cp "$GOBOT_DIR/config/schedule.example.json" "$GOBOT_DIR/config/schedule.json"
        add_manual "Review ~/go-bot/config/schedule.json for check-in timing"
    fi

    # Set Ollama as the fallback model
    # GoBot default is "qwen3-coder" (see src/lib/fallback-llm.ts line 17)
    if [[ -f "$GOBOT_DIR/.env" ]]; then
        # Add Ollama config if not already set
        if ! grep -q "OLLAMA_MODEL" "$GOBOT_DIR/.env"; then
            echo "" >> "$GOBOT_DIR/.env"
            echo "# Local LLM Fallback (Ollama)" >> "$GOBOT_DIR/.env"
            echo "# qwen3-coder is GoBot's default fallback — optimized for coding tasks" >> "$GOBOT_DIR/.env"
            echo "OLLAMA_MODEL=qwen3-coder" >> "$GOBOT_DIR/.env"
            echo "FALLBACK_OFFLINE_ONLY=false" >> "$GOBOT_DIR/.env"
            success "Ollama fallback configured in .env (model: qwen3-coder)"
        fi
    fi

    # Run GoBot's own setup check
    step "Running GoBot prerequisite check..."
    bun run setup 2>/dev/null || warn "GoBot setup check had issues — review output above"

    add_installed "GoBot project setup"
fi

# ── Summary ─────────────────────────────────────────────────────────
header "Setup Complete!"

echo -e "${BOLD}Machine:${NC} $MAC_MODEL (${RAM_GB} GB RAM)"
echo ""

if [[ ${#INSTALLED_ITEMS[@]} -gt 0 ]]; then
    echo -e "${GREEN}${BOLD}Installed:${NC}"
    for item in "${INSTALLED_ITEMS[@]}"; do
        echo -e "  ${GREEN}✔${NC} $item"
    done
    echo ""
fi

if [[ ${#SKIPPED_ITEMS[@]} -gt 0 ]]; then
    echo -e "${BLUE}${BOLD}Already Present:${NC}"
    for item in "${SKIPPED_ITEMS[@]}"; do
        echo -e "  ${BLUE}—${NC} $item"
    done
    echo ""
fi

if [[ ${#MANUAL_STEPS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}${BOLD}Manual Steps Required:${NC}"
    for i in "${!MANUAL_STEPS[@]}"; do
        echo -e "  ${YELLOW}$((i+1)).${NC} ${MANUAL_STEPS[$i]}"
    done
    echo ""
fi

echo -e "${BOLD}━━━ Quick Reference ━━━${NC}"
echo ""
echo -e "${BOLD}Remote Access:${NC}"
echo "  Local SSH:     ssh $(whoami)@$LOCAL_IP"
echo "  Local VNC:     vnc://$LOCAL_IP"
if command -v tailscale &>/dev/null; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "<run tailscale up first>")
    echo "  Tailscale SSH: ssh $(whoami)@$TS_IP"
    echo "  Tailscale VNC: vnc://$TS_IP"
fi
echo ""
echo -e "${BOLD}Ollama (Local LLMs):${NC}"
echo "  GoBot model:   qwen3-coder (auto-used as fallback)"
echo "  Chat:          ollama run qwen3-coder"
echo "  Quick chat:    ollama run llama3.2:3b"
echo "  List models:   ollama list"
echo "  Pull model:    ollama pull <model-name>"
echo "  API endpoint:  http://localhost:11434"
echo ""
echo -e "${BOLD}Open WebUI (ChatGPT-like interface for local models):${NC}"
echo "  Access at:     http://localhost:3080"
echo "  Also from LAN: http://$LOCAL_IP:3080"
if command -v tailscale &>/dev/null; then
    echo "  Via Tailscale: http://$TS_IP:3080"
fi
echo ""
echo -e "${BOLD}LM Studio:${NC}"
echo "  Open the app for a GUI to download and chat with models"
echo "  Supports GGUF models from HuggingFace"
echo ""
echo -e "${BOLD}GoBot:${NC}"
echo "  Directory:     ~/go-bot"
echo "  Start bot:     cd ~/go-bot && bun run start"
echo "  Setup guide:   ~/go-bot/docs/setup-guide.md"
echo "  Health check:  cd ~/go-bot && bun run setup:verify"
echo ""
echo -e "${BOLD}Keyboard Shortcuts (installed apps):${NC}"
echo "  Ctrl+Opt+Arrow    Rectangle: snap window to half/quarter screen"
echo "  Cmd+Space          Raycast: spotlight replacement (or Spotlight)"
echo "  Cmd+\`              Switch windows within same app"
echo ""
echo -e "${BOLD}━━━ Next Steps for Andrew ━━━${NC}"
echo ""
echo "  1. Open Tailscale app → Sign in → Approve this device"
echo "  2. Install Tailscale on your laptop/phone for remote access"
echo "  3. Open Telegram Desktop → Sign in with your account"
echo "  4. Edit ~/go-bot/.env with your API keys:"
echo "     - TELEGRAM_BOT_TOKEN (from @BotFather on Telegram)"
echo "     - TELEGRAM_USER_ID (from @userinfobot on Telegram)"
echo "     - ANTHROPIC_API_KEY (from console.anthropic.com)"
echo "     - SUPABASE_URL + SUPABASE_ANON_KEY (from supabase.com)"
echo "  5. Run: cd ~/go-bot && bun run setup:verify"
echo "  6. Start the bot: bun run start"
echo "  7. For always-on mode: bun run setup:launchd"
echo "  8. Visit http://localhost:3080 to chat with local models via Open WebUI"
echo ""
echo -e "${BOLD}Pro Tips:${NC}"
echo "  - Use Stats menu bar app to watch memory when running large models"
echo "  - Open WebUI at :3080 lets you chat with ALL your Ollama models"
echo "  - GoBot auto-falls back to local Ollama when Claude is unavailable"
echo ""
echo -e "${GREEN}${BOLD}Your Mac Studio is ready to rock and roll! 🤘${NC}"
echo ""
