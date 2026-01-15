#!/bin/bash
set -euo pipefail

# Konfiguration
BASE_DIR="$HOME/homelab-infrastructure"
DOCKER_DIR="$BASE_DIR/docker"
BACKUP_DIR="$BASE_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

echo "🔄 Starting Homelab Backup..."
echo "📂 Scanning for stacks in: $DOCKER_DIR"

# 1. Hitta alla stacks (mappar som har en compose.yaml)
# Vi sparar listan i en array
mapfile -t STACKS < <(find "$DOCKER_DIR" -name "compose.yaml" -exec dirname {} \;)

if [ ${#STACKS[@]} -eq 0 ]; then
    echo "❌ No stacks found!"
    exit 1
fi

echo "found ${#STACKS[@]} stacks."

# 2. Stäng ner alla containers (Säkraste sättet att backa upp databaser)
echo "⏸️  Stopping all stacks for data consistency..."
for stack in "${STACKS[@]}"; do
    echo "   ⬇️  Stopping $(basename "$stack")..."
    cd "$stack" && docker compose down
done

# 3. Utför Backupen (Tar hela docker-mappen, inklusive alla volymer)
echo "📦 Compressing data..."
# Vi exkluderar backups-mappen själv så vi inte backar upp backupen (Inception!)
cd "$BASE_DIR"
tar --exclude='./backups' -czf "$BACKUP_DIR/homelab_backup_$DATE.tar.gz" docker .env scripts

if [ $? -eq 0 ]; then
    echo "✅ Backup created: homelab_backup_$DATE.tar.gz"
else
    echo "❌ Backup failed!"
    # Vi försöker starta allt ändå
fi

# 4. Starta upp allt igen
echo "▶️  Restarting stacks..."
for stack in "${STACKS[@]}"; do
    echo "   ⬆️  Starting $(basename "$stack")..."
    cd "$stack" && docker compose up -d
done

# 5. Städa gamla backups
echo "🧹 Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "✅ Backup Process Complete!"
ls -lh "$BACKUP_DIR/homelab_backup_$DATE.tar.gz"
