#!/bin/bash

# FreeChatGPT Installation Script
# By: 833K-cpu
# Optimized for GTX 2060 (6GB VRAM) + Ryzen 5 2600 + 16GB RAM

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓ ${NC}$1"; }
print_warning() { echo -e "${YELLOW}⚠ ${NC}$1"; }
print_error() { echo -e "${RED}✗ ${NC}$1"; }

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   FreeChatGPT Installation                    ║"
echo "║           Your Personal AI, Completely Free                   ║"
echo "║                                                               ║"
echo "║  By: 833K-cpu                                                ║"
echo "║  GitHub: github.com/833K-cpu/FreeChatGPT                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# System checks
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    print_error "This script requires Linux. Your OS: $OSTYPE"
    exit 1
fi
print_success "Running on Linux"

print_info "Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_success "Python 3 found ($PYTHON_VERSION)"
else
    print_error "Python 3 not found. Please install Python 3.8+"
    exit 1
fi

print_info "Checking system RAM..."
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -ge 14 ]; then
    print_success "RAM: ${TOTAL_RAM}GB ✓"
else
    print_warning "RAM: ${TOTAL_RAM}GB (recommended: 16GB+)"
fi

print_info "Checking GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    print_success "GPU: $GPU_NAME (${GPU_MEMORY}MB VRAM)"
else
    print_warning "NVIDIA GPU not detected. Will use CPU (slower)"
fi

# Install Python dependencies
print_info "Installing Python dependencies..."
pip3 install -q flask requests werkzeug --break-system-packages 2>/dev/null || pip3 install -q flask requests werkzeug
print_success "Python dependencies installed"

# Install Ollama
print_info "Checking Ollama..."
if command -v ollama &> /dev/null; then
    print_success "Ollama already installed"
else
    print_info "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    print_success "Ollama installed"
fi

# Start Ollama
print_info "Starting Ollama service..."
ollama serve &> /dev/null &
OLLAMA_PID=$!
sleep 3

if ps -p $OLLAMA_PID > /dev/null; then
    print_success "Ollama started (PID: $OLLAMA_PID)"
else
    print_warning "Ollama may already be running"
fi

# Model selection
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  AI MODEL SELECTION"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Choose models to download (optimized for GTX 2060):"
echo ""
echo "  ${GREEN}1) Llama 3.2 3B${NC}       - Best all-rounder (2GB, ~3GB VRAM) ${PURPLE}★ RECOMMENDED${NC}"
echo "  2) Mistral 7B 4-bit  - Creative writing (4.1GB, ~5GB VRAM)"
echo "  3) Qwen 2.5 3B       - Fast & multilingual (1.9GB, ~3GB VRAM)"
echo "  4) All of the above  - Download all recommended models"
echo "  5) Skip              - Download later from UI"
echo ""

read -p "Select option (1-5) [1]: " MODEL_CHOICE
MODEL_CHOICE=${MODEL_CHOICE:-1}

case $MODEL_CHOICE in
    1)
        print_info "Downloading Llama 3.2 3B..."
        ollama pull llama3.2:3b && print_success "Llama 3.2 3B installed"
        ;;
    2)
        print_info "Downloading Mistral 7B (4-bit quantized)..."
        ollama pull mistral:7b && print_success "Mistral 7B installed"
        ;;
    3)
        print_info "Downloading Qwen 2.5 3B..."
        ollama pull qwen2.5:3b && print_success "Qwen 2.5 3B installed"
        ;;
    4)
        print_info "Downloading all recommended models..."
        ollama pull llama3.2:3b && print_success "Llama 3.2 3B ✓"
        ollama pull mistral:7b && print_success "Mistral 7B ✓"
        ollama pull qwen2.5:3b && print_success "Qwen 2.5 3B ✓"
        ;;
    5)
        print_info "Skipping model download"
        ;;
    *)
        print_warning "Invalid choice. Using default: Llama 3.2 3B"
        ollama pull llama3.2:3b
        ;;
esac

# Create data directory
mkdir -p data/conversations
print_success "Data directory created"

# Desktop launcher
echo ""
read -p "Create desktop launcher? (y/n) [y]: " CREATE_LAUNCHER
CREATE_LAUNCHER=${CREATE_LAUNCHER:-y}

if [[ "$CREATE_LAUNCHER" =~ ^[Yy]$ ]]; then
    DESKTOP_FILE="$HOME/.local/share/applications/freechatgpt.desktop"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    
    mkdir -p "$HOME/.local/share/applications"
    
    cat > "$DESKTOP_FILE" << EOF
[Desktop Entry]
Type=Application
Name=FreeChatGPT
Comment=Your Personal AI, Completely Free
Exec=bash -c 'cd "$SCRIPT_DIR" && python3 src/server.py'
Icon=robot
Terminal=true
Categories=Development;Utility;Network;
EOF
    
    chmod +x "$DESKTOP_FILE"
    print_success "Desktop launcher created"
fi

# Installation complete
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              🎉 Installation Complete! 🎉                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
print_success "FreeChatGPT is ready!"
echo ""
echo "To start the server:"
echo "  ${GREEN}./scripts/start.sh${NC}"
echo ""
echo "Or manually:"
echo "  ${GREEN}python3 src/server.py${NC}"
echo ""
echo "Then open: ${BLUE}http://localhost:5000${NC}"
echo ""
echo "Features:"
echo "  ✓ ChatGPT-like interface"
echo "  ✓ Multiple conversations saved automatically"
echo "  ✓ File upload support"
echo "  ✓ VirusTotal scanner (API key required)"
echo "  ✓ API mode for integrations"
echo "  ✓ 100% private & free forever"
echo ""
print_info "GitHub: github.com/833K-cpu/FreeChatGPT"
echo ""
