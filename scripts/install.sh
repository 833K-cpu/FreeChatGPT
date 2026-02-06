#!/bin/bash
set -e

G='\033[0;32m'; Y='\033[1;33m'; B='\033[0;34m'; R='\033[0;31m'; N='\033[0m'

echo -e "${B}╔══════════════════════════════════════════════════════════╗${N}"
echo -e "${B}║     FreeChatGPT v3.0 ULTIMATE Installation              ║${N}"
echo -e "${B}║     Your Personal AI, Completely Free                    ║${N}"
echo -e "${B}╚══════════════════════════════════════════════════════════╝${N}"
echo ""

echo -e "${B}ℹ${N}  Checking system..."
if command -v python3 &> /dev/null; then
    echo -e "${G}✅ Python 3 found${N}"
else
    echo -e "${R}❌ Python 3 required${N}"
    exit 1
fi

echo -e "${B}ℹ${N}  Installing Python dependencies..."
pip3 install flask requests werkzeug --break-system-packages 2>/dev/null || pip3 install flask requests werkzeug
echo -e "${G}✅ Python packages installed${N}"

echo -e "${B}ℹ${N}  Checking Ollama..."
if command -v ollama &> /dev/null; then
    echo -e "${G}✅ Ollama installed${N}"
else
    echo -e "${Y}⚠${N}  Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    echo -e "${G}✅ Ollama installed${N}"
fi

echo -e "${B}ℹ${N}  Starting Ollama..."
ollama serve &> /dev/null &
sleep 3
echo -e "${G}✅ Ollama started${N}"

echo ""
echo -e "${B}Choose AI model:${N}"
echo -e "  ${G}1)${N} ⚡ Llama 3.2 3B - Best all-rounder (2GB) ${Y}★ RECOMMENDED${N}"
echo -e "  ${G}2)${N} ✨ Mistral 7B - Creative writing (4GB)"
echo -e "  ${G}3)${N} 🚀 Qwen 2.5 3B - Ultra-fast (2GB)"
echo -e "  ${G}4)${N} All of the above"
echo -e "  ${G}5)${N} Skip"
echo ""
read -p "Select (1-5) [1]: " choice
choice=${choice:-1}

case $choice in
    1) echo -e "${B}ℹ${N}  Downloading Llama 3.2 3B..." && ollama pull llama3.2:3b && echo -e "${G}✅ Installed${N}" ;;
    2) echo -e "${B}ℹ${N}  Downloading Mistral 7B..." && ollama pull mistral:7b && echo -e "${G}✅ Installed${N}" ;;
    3) echo -e "${B}ℹ${N}  Downloading Qwen 2.5 3B..." && ollama pull qwen2.5:3b && echo -e "${G}✅ Installed${N}" ;;
    4) echo -e "${B}ℹ${N}  Downloading all models..." && ollama pull llama3.2:3b && ollama pull mistral:7b && ollama pull qwen2.5:3b && echo -e "${G}✅ All installed${N}" ;;
    *) echo -e "${Y}⚠${N}  Skipped" ;;
esac

mkdir -p data

echo ""
echo -e "${G}╔══════════════════════════════════════════════════════════╗${N}"
echo -e "${G}║              🎉 Installation Complete! 🎉                ║${N}"
echo -e "${G}╚══════════════════════════════════════════════════════════╝${N}"
echo ""
echo -e "Start: ${G}./scripts/start.sh${N}"
echo -e "Then: ${B}http://localhost:5000${N}"
echo ""
