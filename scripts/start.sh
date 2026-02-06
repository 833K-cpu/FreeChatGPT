#!/bin/bash
G='\033[0;32m'; B='\033[0;34m'; N='\033[0m'

echo -e "${B}╔══════════════════════════════════════════════════════════╗${N}"
echo -e "${B}║           Starting FreeChatGPT v3.0 ULTIMATE             ║${N}"
echo -e "${B}╚══════════════════════════════════════════════════════════╝${N}"
echo ""

if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${B}Starting Ollama...${N}"
    ollama serve &> /dev/null &
    sleep 2
    echo -e "${G}✅ Ollama started${N}"
fi

cd "$(dirname "$0")/.."
python3 src/server.py
