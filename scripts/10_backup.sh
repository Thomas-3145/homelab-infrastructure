#!/bin/bash
set -euo pipefail

# Konfiguration
BASE_DIR="$HOME/homelab-infrastructure"
DOCKER_DIR="$BASE_DIR/docker"
BACKUP_DIR="$BASE_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7
BACKUP_FILE="$BACKUP_DIR/homelab_backup_$DATE.tar.gz"
BACKUP_FAILED=0

mkdir -p "$BACKUP_DIR"

echo "🔄 Starting Homelab Backup..."
echo "📂 Scanning for stacks in: $DOCKER_DIR"

# 1. Hitta alla stacks (mappar som har en compose.yaml)
mapfile -t STACKS < <(find "$DOCKER_DIR" -name "compose.yaml" -exec dirname {} \;)

if [[ ${#STACKS[@]} -eq 0 ]]; then
    echo "❌ No stacks found!"
    exit 1
fi

echo "Found ${#STACKS[@]} stacks."

# 2. Stäng ner alla containers (Säkraste sättet att backa upp databaser)
echo "⏸️  Stopping all stacks for data consistency..."
for stack in "${STACKS[@]}"; do
    echo "   ⬇️  Stopping $(basename "$stack")..."
    cd "$stack" && docker compose down || true
done

# 3. Utför Backupen (Tar hela docker-mappen, inklusive alla volymer)
echo "📦 Compressing data..."
cd "$BASE_DIR"
if tar --exclude='./backups' -czf "$BACKUP_FILE" docker .env scripts 2>/dev/null; then
    echo "✅ Backup archive created."
else
    echo "❌ Backup failed! Could not create archive."
    BACKUP_FAILED=1
fi

# 4. Verifiera backupen (om den skapades)
if [[ $BACKUP_FAILED -eq 0 ]]; then
    echo "🔍 Verifying backup integrity..."
    if tar -tzf "$BACKUP_FILE" >/dev/null 2>&1; then
        echo "✅ Backup verified successfully."
    else
        echo "❌ Backup verification failed! Archive may be corrupted."
        BACKUP_FAILED=1
    fi
fi

# 5. Starta upp allt igen (oavsett om backup lyckades)
echo "▶️  Restarting stacks..."
for stack in "${STACKS[@]}"; do
    stack_name=$(basename "$stack")
    echo "   ⬆️  Starting $stack_name..."
    if ! (cd "$stack" && docker compose up -d); then
        echo "   ⚠️  Warning: Failed to start $stack_name"
    fi
done

# 6. Städa gamla backups
echo "🧹 Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

# 7. Slutrapport
echo ""
if [[ $BACKUP_FAILED -eq 1 ]]; then
    echo "❌ Backup Process Failed!"
    exit 1
else
    echo "✅ Backup Process Complete!"
    ls -lh "$BACKUP_FILE"
fi
