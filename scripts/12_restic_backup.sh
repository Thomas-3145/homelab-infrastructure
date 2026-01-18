#!/bin/bash
set -euo pipefail

# ============================================================
# Restic Backup Script för Homelab Infrastructure
# ============================================================
# Skapar inkrementella, krypterade backups med restic.
# Designad för enkel migrering till off-site (NAS/cloud).
# ============================================================

BASE_DIR="$HOME/homelab-infrastructure"
DOCKER_DIR="$BASE_DIR/docker"
ENV_FILE="$BASE_DIR/.env.backup"

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- 1. Ladda konfiguration ---
if [[ ! -f "$ENV_FILE" ]]; then
    log_error ".env.backup saknas!"
    log_info "Skapa den med: cp .env.backup.example .env.backup"
    exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

# --- 2. Validera konfiguration ---
if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    log_error "RESTIC_REPOSITORY är inte satt i .env.backup"
    exit 1
fi

if [[ -z "${RESTIC_PASSWORD:-}" ]] || [[ "$RESTIC_PASSWORD" == "CHANGE_ME_TO_A_SECURE_PASSWORD" ]]; then
    log_error "RESTIC_PASSWORD måste sättas till ett säkert lösenord!"
    exit 1
fi

# Exportera för restic
export RESTIC_REPOSITORY
export RESTIC_PASSWORD

# Sätt standardvärden för retention om de inte finns
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-3}"

log_info "Restic Backup startar..."
log_info "Repository: $RESTIC_REPOSITORY"

# --- 3. Initiera repo om det inte finns ---
if ! restic snapshots &>/dev/null; then
    log_warn "Repository finns inte. Initierar..."

    # Skapa lokal mapp om det är en lokal sökväg
    if [[ "$RESTIC_REPOSITORY" == /* ]]; then
        mkdir -p "$RESTIC_REPOSITORY"
    fi

    restic init
    log_info "Repository initierat!"
fi

# --- 4. Hitta och stoppa alla containers ---
log_info "Söker efter Docker stacks..."
cd "$BASE_DIR"

mapfile -t STACKS < <(find "$DOCKER_DIR" -name "compose.yaml" -exec dirname {} \;)

if [[ ${#STACKS[@]} -eq 0 ]]; then
    log_warn "Inga stacks hittades, fortsätter utan att stoppa containers..."
else
    log_info "Hittade ${#STACKS[@]} stacks. Stoppar för konsistent backup..."
    for stack in "${STACKS[@]}"; do
        stack_name=$(basename "$stack")
        log_info "  Stoppar $stack_name..."
        cd "$stack" && docker compose down 2>/dev/null || true
    done
fi

# --- 5. Utför backup ---
log_info "Skapar backup..."
cd "$BASE_DIR"

# Samla filer att backa upp
BACKUP_PATHS=()
[[ -d "docker" ]] && BACKUP_PATHS+=("docker")
[[ -f ".env" ]] && BACKUP_PATHS+=(".env")
[[ -d "scripts" ]] && BACKUP_PATHS+=("scripts")
[[ -d "configs" ]] && BACKUP_PATHS+=("configs")

if [[ ${#BACKUP_PATHS[@]} -eq 0 ]]; then
    log_error "Inga filer att backa upp!"
    exit 1
fi

log_info "Backar upp: ${BACKUP_PATHS[*]}"

restic backup "${BACKUP_PATHS[@]}" \
    --tag "homelab" \
    --exclude="*.log" \
    --exclude="*.tmp" \
    --exclude="**/work/" \
    --exclude="**/conf/" \
    --exclude="**/data/" \
    --exclude="**/db/" \
    --verbose

# --- 6. Starta containers igen ---
if [[ ${#STACKS[@]} -gt 0 ]]; then
    log_info "Startar om stacks..."
    for stack in "${STACKS[@]}"; do
        stack_name=$(basename "$stack")
        log_info "  Startar $stack_name..."
        cd "$stack" && docker compose up -d 2>/dev/null || true
    done
fi

# --- 7. Retention / Prune ---
log_info "Kör retention policy (behåller: $KEEP_DAILY dagliga, $KEEP_WEEKLY veckovisa, $KEEP_MONTHLY månatliga)..."
restic forget \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY" \
    --prune

# --- 8. Visa statistik ---
log_info "Backup klar! Här är statistiken:"
echo ""
echo "=== Senaste snapshots ==="
restic snapshots --latest 5

echo ""
echo "=== Repository storlek ==="
restic stats

log_info "Restic backup slutförd!"
