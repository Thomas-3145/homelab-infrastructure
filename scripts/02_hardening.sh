#!/bin/bash
# scripts/02_hardening.sh
# Purpose: Secures the server based on YOUR specific ports

set -euo pipefail

# HÄR ÄR DIN PORT - Ändra inte denna om du vill behålla 22456
NEW_SSH_PORT="${SSH_PORT:-22456}"

echo "🛡️  Starting System Hardening..."
echo "⚠️  This will enforce SSH port: $NEW_SSH_PORT"

# Säkerhetsfråga
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 1
fi

# --- 1. Konfigurera SSH ---
echo "Configuring SSH..."

# Backup (alltid bra att ha)
if [[ ! -f /etc/ssh/sshd_config.bak ]]; then
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
fi

# Tvinga porten till 22456 i config-filen
# Detta kommando letar efter rader med "Port ..." och ersätter dem
sudo sed -i "s/^#\?Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config

# Starta om SSH
sudo systemctl restart ssh
echo "SSH configured on port $NEW_SSH_PORT"

# --- 2. Konfigurera Brandvägg (UFW) ---
echo "Configuring Firewall (UFW)..."

# Grundregler
sudo ufw default deny incoming
sudo ufw default allow outgoing

# --- KRITISKA TJÄNSTER ---
sudo ufw allow "$NEW_SSH_PORT"/tcp comment 'Custom SSH'
sudo ufw allow 80/tcp comment 'HTTP / AdGuard'
sudo ufw allow 443/tcp comment 'HTTPS / AdGuard'
sudo ufw allow 53/tcp comment 'DNS TCP'
sudo ufw allow 53/udp comment 'DNS UDP'

# --- DINA APPLIKATIONER (Från din docker ps) ---
sudo ufw allow 5001/tcp comment 'Dockge'
sudo ufw allow 3001/tcp comment 'Uptime Kuma'
sudo ufw allow 3010/tcp comment 'Grafana (Mapped)'
sudo ufw allow 8001/tcp comment 'Vaultwarden (Mapped)'
sudo ufw allow 3000/tcp comment 'AdGuard Admin'

# --- MONITORING (Felsökning) ---
sudo ufw allow 9090/tcp comment 'Prometheus'
sudo ufw allow 8080/tcp comment 'cAdvisor'

# --- INFRASTRUKTUR ---
# Tailscale behövs ofta för direktkoppling (UDP)
sudo ufw allow 41641/udp comment 'Tailscale Direct'

# Aktivera reglerna
sudo ufw --force enable
sudo ufw reload

echo "Firewall rules updated!"

# --- 3. Konfigurera Fail2Ban ---
echo "Configuring Fail2Ban..."

# Se till att fail2ban vet att vi bytt SSH-port
sudo tee /etc/fail2ban/jail.d/sshd-custom.conf > /dev/null <<EOF
[sshd]
enabled = true
port = $NEW_SSH_PORT
maxretry = 3
bantime = 1h
EOF

sudo systemctl restart fail2ban

echo "✅ Hardening Complete!"
echo "👉 Verify access: ssh -p $NEW_SSH_PORT $USER@<YOUR-IP>"
