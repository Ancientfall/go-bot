#!/bin/bash
# ============================================================
# GoBot — Mac Studio Setup Script
# ============================================================
# One command to set up everything you need:
#   ./setup/mac-studio-setup.sh
#
# Safe to re-run — it skips anything already installed.
# ============================================================

# --- Colors & Symbols ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
PASS="${GREEN}✓${NC}"
FAIL="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"

# --- Error Tracking ---
ERRORS=()
INSTALLED=()
SKIPPED=()

# --- Resolve project root (parent of setup/) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Helper Functions ---

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "\n${BOLD}  [$1] $2${NC}"
    echo -e "  ${DIM}$3${NC}\n"
}

log_pass() {
    echo -e "  ${PASS} $1"
    INSTALLED+=("$1")
}

log_fail() {
    echo -e "  ${FAIL} $1"
    ERRORS+=("$1")
}

log_skip() {
    echo -e "  ${PASS} $1 ${DIM}(already installed)${NC}"
    SKIPPED+=("$1")
}

log_warn() {
    echo -e "  ${WARN} $1"
}

log_info() {
    echo -e "  ${DIM}$1${NC}"
}

# Ask a yes/no question. Defaults to Yes (just press Enter).
ask_yes_no() {
    local prompt="$1"
    local answer
    echo -ne "  ${BOLD}${prompt}${NC} [Y/n] "
    read -r answer
    answer="${answer:-y}"
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

command_exists() {
    command -v "$1" &>/dev/null
}

app_installed() {
    [ -d "/Applications/$1.app" ] || [ -d "$HOME/Applications/$1.app" ]
}

ensure_path() {
    # Add a directory to PATH for the current session if not already there
    local dir="$1"
    if [[ ":$PATH:" != *":$dir:"* ]] && [ -d "$dir" ]; then
        export PATH="$dir:$PATH"
    fi
}

# ============================================================
# SECTION 0: Welcome + System Check
# ============================================================

clear
echo ""
echo -e "${CYAN}${BOLD}"
echo "   ╔═══════════════════════════════════════════╗"
echo "   ║                                           ║"
echo "   ║       🤖  GoBot Mac Studio Setup  🤖      ║"
echo "   ║                                           ║"
echo "   ╚═══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${DIM}This script will set up your Mac Studio with:${NC}"
echo -e "  ${DIM}  • Developer tools (Git, Node.js, Bun, Python)${NC}"
echo -e "  ${DIM}  • Local AI models (Ollama — runs on your Mac, 100% private)${NC}"
echo -e "  ${DIM}  • Open WebUI (a ChatGPT-like interface for local AI)${NC}"
echo -e "  ${DIM}  • Claude Code (AI coding assistant)${NC}"
echo -e "  ${DIM}  • GoBot (your personal Telegram AI assistant)${NC}"
echo ""
echo -e "  ${DIM}It will ask before each step. Just press Enter to accept.${NC}"
echo -e "  ${DIM}If anything goes wrong, just run this script again — it picks up where it left off.${NC}"
echo ""

# Check macOS
if [ "$(uname -s)" != "Darwin" ]; then
    echo -e "  ${FAIL} This script only runs on macOS. Detected: $(uname -s)"
    exit 1
fi

# Check Apple Silicon
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    log_warn "Expected Apple Silicon (arm64) but detected: $ARCH"
    log_warn "Some features may not work optimally."
fi

# Check RAM
RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
RAM_GB=$((RAM_BYTES / 1073741824))
echo -e "  ${PASS} macOS detected — $(sw_vers -productVersion)"
echo -e "  ${PASS} Chip: Apple Silicon (${ARCH})"
echo -e "  ${PASS} Memory: ${RAM_GB} GB unified memory"

if [ "$RAM_GB" -ge 32 ]; then
    echo -e "  ${DIM}  Great! ${RAM_GB}GB is perfect for running local AI models (7B–14B parameters).${NC}"
elif [ "$RAM_GB" -ge 16 ]; then
    echo -e "  ${DIM}  ${RAM_GB}GB is good for smaller AI models (3B–7B parameters).${NC}"
else
    log_warn "${RAM_GB}GB RAM is limited for local AI models. Smaller models recommended."
fi

echo ""
echo -e "  ${BOLD}Total estimated time: 30–60 minutes${NC} (mostly downloading AI models)"
echo ""

if ! ask_yes_no "Ready to start?"; then
    echo -e "\n  No problem! Run this script again whenever you're ready.\n"
    exit 0
fi

# ============================================================
# SECTION 1: Xcode Command Line Tools
# ============================================================

print_step "1/9" "Xcode Command Line Tools" "Apple's core developer tools — needed by almost everything else"

if xcode-select -p &>/dev/null; then
    log_skip "Xcode Command Line Tools"
else
    echo -e "  ${WARN} Xcode Command Line Tools not found."
    echo -e "  ${BOLD}A popup window will appear — click 'Install' and wait.${NC}"
    echo -e "  ${DIM}This usually takes 5–10 minutes.${NC}"
    echo ""

    xcode-select --install 2>/dev/null

    echo -e "  Waiting for installation to finish..."
    echo -e "  ${DIM}(If no popup appeared, it may already be installing.)${NC}"

    # Wait up to 10 minutes
    TIMEOUT=600
    ELAPSED=0
    while ! xcode-select -p &>/dev/null; do
        sleep 10
        ELAPSED=$((ELAPSED + 10))
        if [ $ELAPSED -ge $TIMEOUT ]; then
            log_fail "Xcode Command Line Tools (timed out — try running 'xcode-select --install' manually)"
            break
        fi
    done

    if xcode-select -p &>/dev/null; then
        log_pass "Xcode Command Line Tools"
    fi
fi

# ============================================================
# SECTION 2: Homebrew
# ============================================================

print_step "2/9" "Homebrew" "A package manager for macOS — like an app store for developer tools"

# Source Homebrew if it exists but isn't in PATH yet
if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if command_exists brew; then
    log_skip "Homebrew"
else
    echo -e "  Installing Homebrew..."
    echo -e "  ${DIM}You may be asked for your Mac password — that's normal.${NC}"
    echo ""

    if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
        # Add Homebrew to PATH for this session
        if [ -f /opt/homebrew/bin/brew ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"

            # Make it permanent (Apple Silicon path)
            if ! grep -q 'brew shellenv' ~/.zprofile 2>/dev/null; then
                echo '' >> ~/.zprofile
                echo '# Homebrew' >> ~/.zprofile
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
            fi
        fi

        if command_exists brew; then
            log_pass "Homebrew"
        else
            log_fail "Homebrew (installed but not in PATH — restart Terminal and re-run)"
        fi
    else
        log_fail "Homebrew"
    fi
fi

# ============================================================
# SECTION 3: Core Development Tools
# ============================================================

print_step "3/9" "Core Development Tools" "Git, Node.js, Bun, Python, and uv — the essentials"

# Git
if command_exists git; then
    log_skip "Git ($(git --version 2>/dev/null | head -1))"
else
    if brew install git 2>/dev/null; then
        log_pass "Git"
    else
        log_fail "Git"
    fi
fi

# Node.js (needed for Claude Code CLI)
if command_exists node; then
    log_skip "Node.js ($(node --version 2>/dev/null))"
else
    echo -e "  Installing Node.js... ${DIM}(needed for Claude Code CLI)${NC}"
    if brew install node 2>/dev/null; then
        log_pass "Node.js"
    else
        log_fail "Node.js"
    fi
fi

# Bun (GoBot's runtime)
ensure_path "$HOME/.bun/bin"
if command_exists bun; then
    log_skip "Bun ($(bun --version 2>/dev/null))"
else
    echo -e "  Installing Bun... ${DIM}(GoBot's runtime — faster than Node.js)${NC}"
    if curl -fsSL https://bun.sh/install | bash 2>/dev/null; then
        ensure_path "$HOME/.bun/bin"

        # Make it permanent
        if ! grep -q 'BUN_INSTALL' ~/.zshrc 2>/dev/null; then
            echo '' >> ~/.zshrc
            echo '# Bun' >> ~/.zshrc
            echo 'export BUN_INSTALL="$HOME/.bun"' >> ~/.zshrc
            echo 'export PATH="$BUN_INSTALL/bin:$PATH"' >> ~/.zshrc
        fi

        if command_exists bun; then
            log_pass "Bun"
        else
            log_fail "Bun (installed but not in PATH — restart Terminal and re-run)"
        fi
    else
        log_fail "Bun"
    fi
fi

# Python 3 (useful for AI/ML experimentation)
if command_exists python3; then
    log_skip "Python 3 ($(python3 --version 2>/dev/null))"
else
    echo -e "  Installing Python 3... ${DIM}(useful for AI/ML experimentation)${NC}"
    if brew install python3 2>/dev/null; then
        log_pass "Python 3"
    else
        log_fail "Python 3"
    fi
fi

# uv (modern Python package manager)
if command_exists uv; then
    log_skip "uv (Python package manager)"
else
    echo -e "  Installing uv... ${DIM}(modern Python package manager — much faster than pip)${NC}"
    if brew install uv 2>/dev/null; then
        log_pass "uv"
    else
        log_fail "uv"
    fi
fi

# ============================================================
# SECTION 4: Applications
# ============================================================

print_step "4/9" "Applications" "Optional but recommended apps"

# Visual Studio Code
if app_installed "Visual Studio Code"; then
    log_skip "Visual Studio Code"
else
    echo -e "  ${DIM}Visual Studio Code is a code editor — great for reading and editing files.${NC}"
    if ask_yes_no "Install Visual Studio Code?"; then
        if brew install --cask visual-studio-code 2>/dev/null; then
            log_pass "Visual Studio Code"
        else
            log_fail "Visual Studio Code"
        fi
    else
        log_info "Skipped Visual Studio Code"
    fi
fi

# iTerm2
if app_installed "iTerm"; then
    log_skip "iTerm2"
else
    echo -e "  ${DIM}iTerm2 is a better terminal — split panes, search, and more.${NC}"
    if ask_yes_no "Install iTerm2?"; then
        if brew install --cask iterm2 2>/dev/null; then
            log_pass "iTerm2"
        else
            log_fail "iTerm2"
        fi
    else
        log_info "Skipped iTerm2"
    fi
fi

# Tailscale
if app_installed "Tailscale"; then
    log_skip "Tailscale"
else
    echo -e "  ${DIM}Tailscale lets you securely access this Mac from anywhere — like a private VPN.${NC}"
    if ask_yes_no "Install Tailscale?"; then
        if brew install --cask tailscale 2>/dev/null; then
            log_pass "Tailscale"
        else
            log_fail "Tailscale"
        fi
    else
        log_info "Skipped Tailscale"
    fi
fi

# ============================================================
# SECTION 5: Ollama + Local AI Models
# ============================================================

print_step "5/9" "Ollama + Local AI Models" "Run AI models 100% locally on your Mac — no internet needed, completely private"

# Install Ollama
if command_exists ollama; then
    log_skip "Ollama"
else
    echo -e "  Installing Ollama... ${DIM}(the engine that runs local AI models)${NC}"
    if brew install ollama 2>/dev/null; then
        log_pass "Ollama"
    else
        log_fail "Ollama"
    fi
fi

# Start Ollama service
if command_exists ollama; then
    echo -e "  Starting Ollama service..."
    brew services start ollama 2>/dev/null || true

    # Wait for Ollama API to be ready
    echo -e "  ${DIM}Waiting for Ollama to start...${NC}"
    OLLAMA_READY=false
    for i in $(seq 1 30); do
        if curl -s http://localhost:11434/api/version &>/dev/null; then
            OLLAMA_READY=true
            break
        fi
        sleep 1
    done

    if [ "$OLLAMA_READY" = true ]; then
        echo -e "  ${PASS} Ollama is running"
    else
        log_warn "Ollama started but API not responding yet. Models will be pulled once it's ready."
    fi

    # Pull AI Models
    if [ "$OLLAMA_READY" = true ]; then
        echo ""
        echo -e "  ${BOLD}Now let's download some AI models.${NC}"
        echo -e "  ${DIM}With ${RAM_GB}GB of memory, your Mac can run these models well.${NC}"
        echo -e "  ${DIM}Models only use memory while actively running — they unload after 5 minutes of idle time.${NC}"
        echo ""

        # qwen3-coder (required for GoBot)
        if ollama list 2>/dev/null | grep -q "qwen3-coder"; then
            log_skip "qwen3-coder model"
        else
            echo -e "  ${DIM}qwen3-coder (~4.7GB) — GoBot's fallback AI model. ${BOLD}Recommended.${NC}"
            if ask_yes_no "Download qwen3-coder?"; then
                echo -e "  Downloading qwen3-coder... ${DIM}(this may take a few minutes)${NC}"
                if ollama pull qwen3-coder; then
                    log_pass "qwen3-coder model"
                else
                    log_fail "qwen3-coder model"
                fi
            else
                log_info "Skipped qwen3-coder"
            fi
        fi

        # llama3.2 (great starter model)
        if ollama list 2>/dev/null | grep -q "llama3.2"; then
            log_skip "llama3.2 model"
        else
            echo -e "  ${DIM}llama3.2 (~2GB) — Meta's fast model. Great for quick questions and learning.${NC}"
            if ask_yes_no "Download llama3.2?"; then
                echo -e "  Downloading llama3.2..."
                if ollama pull llama3.2; then
                    log_pass "llama3.2 model"
                else
                    log_fail "llama3.2 model"
                fi
            else
                log_info "Skipped llama3.2"
            fi
        fi

        # mistral (good at writing)
        if ollama list 2>/dev/null | grep -q "mistral"; then
            log_skip "mistral model"
        else
            echo -e "  ${DIM}mistral (~4.1GB) — Good at writing, summarization, and general tasks.${NC}"
            if ask_yes_no "Download mistral?"; then
                echo -e "  Downloading mistral..."
                if ollama pull mistral; then
                    log_pass "mistral model"
                else
                    log_fail "mistral model"
                fi
            else
                log_info "Skipped mistral"
            fi
        fi

        # deepseek-r1:14b (larger reasoning model — only offer for 32GB+)
        if [ "$RAM_GB" -ge 32 ]; then
            if ollama list 2>/dev/null | grep -q "deepseek-r1:14b"; then
                log_skip "deepseek-r1:14b model"
            else
                echo -e "  ${DIM}deepseek-r1:14b (~9GB) — A larger model that's great at reasoning and analysis.${NC}"
                echo -e "  ${DIM}This one takes longer to download and uses more memory.${NC}"
                if ask_yes_no "Download deepseek-r1:14b?"; then
                    echo -e "  Downloading deepseek-r1:14b... ${DIM}(this is a big one — may take 10+ minutes)${NC}"
                    if ollama pull deepseek-r1:14b; then
                        log_pass "deepseek-r1:14b model"
                    else
                        log_fail "deepseek-r1:14b model"
                    fi
                else
                    log_info "Skipped deepseek-r1:14b"
                fi
            fi
        fi
    fi
fi

# ============================================================
# SECTION 6: Open WebUI
# ============================================================

print_step "6/9" "Open WebUI" "A ChatGPT-like web interface for your local AI models"

ensure_path "$HOME/.local/bin"

if command_exists open-webui; then
    log_skip "Open WebUI"
else
    echo -e "  ${DIM}Open WebUI gives you a beautiful chat interface at http://localhost:8080${NC}"
    echo -e "  ${DIM}You can chat with any of your local AI models through your web browser.${NC}"
    echo ""
    if ask_yes_no "Install Open WebUI?"; then
        echo -e "  Installing Open WebUI... ${DIM}(this downloads a lot of Python packages — may take a few minutes)${NC}"
        if command_exists uv; then
            if uv tool install open-webui 2>/dev/null; then
                ensure_path "$HOME/.local/bin"
                log_pass "Open WebUI"
            else
                log_fail "Open WebUI (uv install failed)"
            fi
        elif command_exists pip3; then
            if pip3 install open-webui 2>/dev/null; then
                log_pass "Open WebUI"
            else
                log_fail "Open WebUI (pip install failed)"
            fi
        else
            log_fail "Open WebUI (no package manager available)"
        fi
    else
        log_info "Skipped Open WebUI"
    fi
fi

# Create launchd plist for Open WebUI (auto-start on login)
OPENWEBUI_BIN=$(which open-webui 2>/dev/null || echo "")
OPENWEBUI_PLIST="$HOME/Library/LaunchAgents/com.openwebui.server.plist"

if [ -n "$OPENWEBUI_BIN" ] && [ ! -f "$OPENWEBUI_PLIST" ]; then
    echo -e "  Setting up Open WebUI to start automatically..."
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$OPENWEBUI_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openwebui.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>${OPENWEBUI_BIN}</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Logs/open-webui.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Logs/open-webui-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${HOME}/.local/bin</string>
    </dict>
</dict>
</plist>
PLIST
    launchctl load "$OPENWEBUI_PLIST" 2>/dev/null
    log_pass "Open WebUI auto-start configured"
elif [ -f "$OPENWEBUI_PLIST" ]; then
    log_skip "Open WebUI auto-start"
fi

# ============================================================
# SECTION 7: Claude Code CLI
# ============================================================

print_step "7/9" "Claude Code" "Anthropic's AI coding assistant — use it right in the terminal"

if command_exists claude; then
    log_skip "Claude Code CLI ($(claude --version 2>/dev/null || echo 'installed'))"
else
    if command_exists npm; then
        echo -e "  Installing Claude Code CLI..."
        if npm install -g @anthropic-ai/claude-code 2>/dev/null; then
            log_pass "Claude Code CLI"
        else
            log_fail "Claude Code CLI"
        fi
    else
        log_fail "Claude Code CLI (npm not available — Node.js needed first)"
    fi
fi

# ============================================================
# SECTION 8: GoBot Project Setup
# ============================================================

print_step "8/9" "GoBot Project Setup" "Installing GoBot's dependencies and creating configuration files"

cd "$PROJECT_ROOT"

# Install npm/bun dependencies
if command_exists bun; then
    echo -e "  Installing GoBot dependencies..."
    if bun install 2>/dev/null; then
        log_pass "GoBot dependencies (bun install)"
    else
        log_fail "GoBot dependencies (bun install)"
    fi
else
    log_fail "GoBot dependencies (bun not found)"
fi

# Create required directories
for dir in logs temp uploads config; do
    mkdir -p "$PROJECT_ROOT/$dir"
done
echo -e "  ${PASS} Created project directories"

# Set up .env file
ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"

if [ -f "$ENV_FILE" ]; then
    log_skip ".env configuration file"
else
    if [ -f "$ENV_EXAMPLE" ]; then
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        log_pass ".env created from template"
    else
        log_fail ".env (no .env.example found)"
    fi
fi

# Set Ollama defaults in .env
if [ -f "$ENV_FILE" ]; then
    # Set OLLAMA_MODEL if it's still commented out or default
    if grep -q "^# OLLAMA_MODEL=" "$ENV_FILE"; then
        sed -i '' 's/^# OLLAMA_MODEL=.*/OLLAMA_MODEL=qwen3-coder/' "$ENV_FILE"
        echo -e "  ${PASS} Set OLLAMA_MODEL=qwen3-coder in .env"
    elif ! grep -q "^OLLAMA_MODEL=" "$ENV_FILE"; then
        echo "" >> "$ENV_FILE"
        echo "OLLAMA_MODEL=qwen3-coder" >> "$ENV_FILE"
        echo -e "  ${PASS} Added OLLAMA_MODEL=qwen3-coder to .env"
    fi

    # Enable offline-only fallback
    if grep -q "^# FALLBACK_OFFLINE_ONLY=" "$ENV_FILE"; then
        sed -i '' 's/^# FALLBACK_OFFLINE_ONLY=.*/FALLBACK_OFFLINE_ONLY=true/' "$ENV_FILE"
        echo -e "  ${PASS} Enabled local-only AI fallback in .env"
    elif ! grep -q "^FALLBACK_OFFLINE_ONLY=" "$ENV_FILE"; then
        echo "FALLBACK_OFFLINE_ONLY=true" >> "$ENV_FILE"
        echo -e "  ${PASS} Enabled local-only AI fallback in .env"
    fi
fi

echo ""
echo -e "  ${WARN} ${BOLD}You still need to add your API keys to .env${NC}"
echo -e "  ${DIM}  The setup guide will walk you through this:${NC}"
echo -e "  ${DIM}  ${PROJECT_ROOT}/docs/mac-studio-setup-guide.md${NC}"

# ============================================================
# SECTION 9: Summary + Next Steps
# ============================================================

print_header "Setup Complete!"

# Summary table
echo -e "  ${BOLD}What was installed:${NC}"
echo ""

for item in "${INSTALLED[@]}"; do
    echo -e "    ${PASS} $item"
done
for item in "${SKIPPED[@]}"; do
    echo -e "    ${PASS} $item ${DIM}(was already installed)${NC}"
done

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo ""
    echo -e "  ${BOLD}${RED}Issues encountered:${NC}"
    for item in "${ERRORS[@]}"; do
        echo -e "    ${FAIL} $item"
    done
    echo ""
    echo -e "  ${DIM}Don't worry — you can re-run this script to retry failed items.${NC}"
fi

echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}  What to Do Next${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}1. Try your local AI right now!${NC}"
echo -e "     Open your web browser and go to:"
echo -e "     ${CYAN}http://localhost:8080${NC}"
echo -e "     ${DIM}This is Open WebUI — a ChatGPT-like interface for your local AI models.${NC}"
echo -e "     ${DIM}Create an account (it's local, just for you) and start chatting!${NC}"
echo ""
echo -e "  ${BOLD}2. Try AI in the terminal:${NC}"
echo -e "     ${CYAN}ollama run llama3.2${NC}"
echo -e "     ${DIM}Type a question, press Enter. Type /bye to exit.${NC}"
echo ""
echo -e "  ${BOLD}3. Set up GoBot (your Telegram AI assistant):${NC}"
echo -e "     Read the detailed guide at:"
echo -e "     ${CYAN}${PROJECT_ROOT}/docs/mac-studio-setup-guide.md${NC}"
echo -e "     ${DIM}This walks you through setting up Telegram, Supabase, and more.${NC}"
echo ""
echo -e "  ${BOLD}4. Try Claude Code:${NC}"
echo -e "     ${CYAN}claude${NC}"
echo -e "     ${DIM}Type 'claude' in Terminal to start an AI coding assistant.${NC}"
echo ""
echo -e "  ${DIM}Need help? Re-run this script anytime — it's safe to run again.${NC}"
echo ""
