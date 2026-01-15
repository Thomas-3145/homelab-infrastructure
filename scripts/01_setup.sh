#!/bin/bash
# scripts/01_setup.sh
# Purpose: Installs software and base packages

set -euo pipefail

echo "🔧 Starting System Setup..."

# Uppdatera systemet
sudo apt update && sudo apt upgrade -y

# Installera verktyg
echo "Installing base packages..."
sudo apt install -y curl wget git htop vim ufw fail2ban net-tools ca-certificates gnupg lsb-release

# Installera Docker (om det inte finns)
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    
    # Lägg till användaren i docker-gruppen
    sudo usermod -aG docker "$USER"
    echo "User added to Docker group."
else
    echo "Docker already installed."
fi

# Tailscale
if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# Skapa mappar och .env
if [[ ! -f .env ]]; then
    echo "Creating empty .env file (Please edit it later!)"
    touch .env
fi

# Skapa nödvändiga mappar för dina stacks
mkdir -p docker/{adguard/{work,conf},dockge/data}

echo "✅ Setup Phase Complete."
