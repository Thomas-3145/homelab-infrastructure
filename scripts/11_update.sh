#!/bin/bash
set -euo pipefail

BASE_DIR="$HOME/homelab-infrastructure"

echo "🔄 Updating Homelab..."

# 1. Uppdatera OS (Linux)
echo "📦 Updating System Packages (apt)..."
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

# 2. Uppdatera Infrastruktur-koden (Git)
echo "📥 Updating Git Repository..."
if [[ -d "$BASE_DIR" ]]; then
    cd "$BASE_DIR"
    git pull
else
    echo "⚠️  Git repo not found at $BASE_DIR"
fi

# 3. Uppdatera Containers (Via Watchtower)
# Vi kör en engångs-körning av Watchtower som letar uppdateringar, installerar dem och sen stänger ner sig själv.
echo "🐳 Checking for Docker Container updates (via Watchtower)..."
docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower \
    --run-once --cleanup

echo "✅ Update Complete!"
