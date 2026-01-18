#!/bin/bash
set -euo pipefail

# ============================================================
# Restic Restore Script för Homelab Infrastructure
# ============================================================
# Återställer backups skapade med 12_restic_backup.sh
# ============================================================

BASE_DIR="$HOME/homelab-infrastructure"
ENV_FILE="$BASE_DIR/.env.backup"

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    echo -e "${CYAN}Restic Restore - Homelab Infrastructure${NC}"
    echo ""
    echo "Användning:"
    echo "  $0 list                    - Visa alla snapshots"
    echo "  $0 files <snapshot>        - Lista filer i en snapshot"
    echo "  $0 restore <snapshot>      - Återställ snapshot till ./restore-DATUM/"
    echo "  $0 restore <snapshot> <path> - Återställ till specifik sökväg"
    echo ""
    echo "Exempel:"
    echo "  $0 list"
    echo "  $0 files latest"
    echo "  $0 files abc123"
    echo "  $0 restore latest"
    echo "  $0 restore abc123 /tmp/restore"
    echo ""
}

# --- Ladda konfiguration ---
load_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error ".env.backup saknas!"
        log_info "Skapa den med: cp .env.backup.example .env.backup"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$ENV_FILE"

    if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
        log_error "RESTIC_REPOSITORY är inte satt i .env.backup"
        exit 1
    fi

    if [[ -z "${RESTIC_PASSWORD:-}" ]]; then
        log_error "RESTIC_PASSWORD är inte satt i .env.backup"
        exit 1
    fi

    export RESTIC_REPOSITORY
    export RESTIC_PASSWORD
}

# --- Kommando: list ---
cmd_list() {
    log_info "Hämtar snapshots från: $RESTIC_REPOSITORY"
    echo ""
    restic snapshots
}

# --- Kommando: files ---
cmd_files() {
    local snapshot="${1:-}"

    if [[ -z "$snapshot" ]]; then
        log_error "Ange vilken snapshot du vill lista filer för"
        echo "Exempel: $0 files latest"
        exit 1
    fi

    log_info "Listar filer i snapshot: $snapshot"
    echo ""
    restic ls "$snapshot"
}

# --- Kommando: restore ---
cmd_restore() {
    local snapshot="${1:-}"
    local target="${2:-}"

    if [[ -z "$snapshot" ]]; then
        log_error "Ange vilken snapshot du vill återställa"
        echo "Exempel: $0 restore latest"
        exit 1
    fi

    # Sätt default restore-mapp med datum
    if [[ -z "$target" ]]; then
        target="$BASE_DIR/restore-$(date +%Y%m%d_%H%M%S)"
    fi

    log_warn "Detta kommer återställa snapshot '$snapshot' till:"
    echo "  $target"
    echo ""
    read -rp "Fortsätt? (y/N) " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Avbrutet."
        exit 0
    fi

    mkdir -p "$target"

    log_info "Återställer snapshot '$snapshot' till '$target'..."
    restic restore "$snapshot" --target "$target" --verbose

    log_info "Återställning klar!"
    echo ""
    echo "Filer återställda till: $target"
    echo ""
    echo "Nästa steg (om du vill ersätta nuvarande installation):"
    echo "  1. Stoppa alla containers: cd docker/<stack> && docker compose down"
    echo "  2. Kopiera filer: cp -r $target/* $BASE_DIR/"
    echo "  3. Starta containers: cd docker/<stack> && docker compose up -d"
    echo ""
    log_warn "OBS: Kontrollera filerna innan du ersätter!"
}

# --- Main ---
main() {
    local command="${1:-}"

    if [[ -z "$command" ]]; then
        show_usage
        exit 0
    fi

    load_config

    case "$command" in
        list)
            cmd_list
            ;;
        files)
            cmd_files "${2:-}"
            ;;
        restore)
            cmd_restore "${2:-}" "${3:-}"
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            log_error "Okänt kommando: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
