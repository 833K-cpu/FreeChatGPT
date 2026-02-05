#!/bin/bash

# FreeChatGPT Startup Script
# By: 833K-cpu

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   Starting FreeChatGPT                        ║"
echo "║          Your Personal AI, Completely Free                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if Ollama is running
if ! pgrep -x "ollama" > /dev/null; then
    echo -e "${YELLOW}⚠ Ollama not running. Starting...${NC}"
    ollama serve &> /dev/null &
    sleep 3
    echo -e "${GREEN}✓ Ollama started${NC}"
else
    echo -e "${GREEN}✓ Ollama is running${NC}"
fi

# Start server
echo -e "${BLUE}ℹ Starting web server...${NC}"
echo ""
python3 src/server.py
