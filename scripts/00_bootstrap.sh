#!/bin/bash
# scripts/00_bootstrap.sh
# Purpose: Clones the repo and triggers setup & hardening
# Run as normal user (not root)

set -euo pipefail

# Konfiguration
REPO_URL="https://github.com/Thomas-3145/homelab-infrastructure"
INSTALL_DIR="$HOME/homelab-infrastructure"

echo "🚀 Starting Bootstrap..."

# 1. Installera git om det saknas (för att kunna klona)
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    sudo apt update && sudo apt install -y git
fi

# 2. Klona eller uppdatera repot
if [[ -d "$INSTALL_DIR" ]]; then
    echo "📂 Repository exists. Pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "📂 Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 3. Gör scripten körbara
chmod +x scripts/*.sh

# 4. Kör Setup (Installera program)
echo "------------------------------------------------"
echo "📦 Running 01_setup.sh..."
./scripts/01_setup.sh

# 5. Kör Hardening (Säkerhet)
echo "------------------------------------------------"
read -p "🔒 Do you want to run system hardening (Change SSH port, UFW)? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ./scripts/02_hardening.sh
else
    echo "Skipping hardening."
fi

echo "✅ Bootstrap Complete!"
