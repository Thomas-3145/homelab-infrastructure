#!/bin/bash
set -euo pipefail

# ============================================================
# Multipass VM Creator - Snabb testmiljö
# ============================================================
# Skapar en Ubuntu VM för att testa scripts och konfigurationer.
# ============================================================

# Standardvärden
DEFAULT_NAME="test-vm"
DEFAULT_MEMORY="2G"
DEFAULT_DISK="20G"
DEFAULT_CPUS="2"
DEFAULT_IMAGE="22.04"  # Ubuntu LTS

# Färger
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_usage() {
    echo -e "${CYAN}Multipass VM Creator${NC}"
    echo ""
    echo "Användning:"
    echo "  $0 create [namn]           - Skapa ny VM"
    echo "  $0 create [namn] --bridge  - Skapa VM med bridge-nätverk (statisk IP)"
    echo "  $0 list                    - Lista alla VMs"
    echo "  $0 shell [namn]            - Öppna shell i VM"
    echo "  $0 ssh [namn]              - SSH till VM (med din nyckel)"
    echo "  $0 delete [namn]           - Ta bort VM"
    echo "  $0 ip [namn]               - Visa VM:ens IP"
    echo ""
    echo "Exempel:"
    echo "  $0 create                  # Skapar 'test-vm'"
    echo "  $0 create homelab-test     # Skapar 'homelab-test'"
    echo "  $0 ssh homelab-test        # SSH in"
    echo "  $0 delete homelab-test     # Radera när du är klar"
    echo ""
    echo "Miljövariabler (valfria):"
    echo "  VM_MEMORY=$DEFAULT_MEMORY  VM_DISK=$DEFAULT_DISK  VM_CPUS=$DEFAULT_CPUS"
    echo ""
}

check_multipass() {
    if command -v multipass &>/dev/null; then
        return 0
    fi

    log_warn "Multipass är inte installerat."
    echo ""
    read -rp "Vill du installera Multipass nu? (Y/n) " install_choice

    if [[ "$install_choice" =~ ^[Nn]$ ]]; then
        log_info "Avbrutet. Installera manuellt: https://multipass.run"
        exit 1
    fi

    # Detektera OS och installera
    if [[ -f /etc/os-release ]]; then
        # Linux
        if command -v snap &>/dev/null; then
            log_info "Installerar Multipass via snap..."
            sudo snap install multipass
        elif command -v apt &>/dev/null; then
            log_info "Installerar snapd först..."
            sudo apt update && sudo apt install -y snapd
            sudo snap install multipass
        else
            log_error "Kunde inte hitta snap eller apt. Installera manuellt:"
            echo "  https://multipass.run"
            exit 1
        fi
    elif [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        if command -v brew &>/dev/null; then
            log_info "Installerar Multipass via Homebrew..."
            brew install --cask multipass
        else
            log_error "Homebrew saknas. Installera från: https://multipass.run"
            exit 1
        fi
    else
        log_error "Okänt operativsystem. Installera manuellt: https://multipass.run"
        exit 1
    fi

    # Verifiera installation
    if command -v multipass &>/dev/null; then
        log_info "Multipass installerat!"
        multipass version
    else
        log_error "Installation misslyckades."
        exit 1
    fi
}

get_vm_ip() {
    local name="$1"
    multipass info "$name" --format csv 2>/dev/null | tail -1 | cut -d',' -f3
}

wait_for_vm() {
    local name="$1"
    local max_wait=60
    local waited=0

    echo -n "Väntar på VM"
    while [[ $waited -lt $max_wait ]]; do
        if multipass info "$name" &>/dev/null; then
            local state
            state=$(multipass info "$name" --format csv | tail -1 | cut -d',' -f2)
            if [[ "$state" == "Running" ]]; then
                echo " klar!"
                return 0
            fi
        fi
        echo -n "."
        sleep 2
        ((waited+=2))
    done
    echo " timeout!"
    return 1
}

cmd_create() {
    local name="${1:-$DEFAULT_NAME}"
    local use_bridge=0

    # Kolla om --bridge flaggan finns
    for arg in "$@"; do
        if [[ "$arg" == "--bridge" ]]; then
            use_bridge=1
        fi
    done

    local memory="${VM_MEMORY:-$DEFAULT_MEMORY}"
    local disk="${VM_DISK:-$DEFAULT_DISK}"
    local cpus="${VM_CPUS:-$DEFAULT_CPUS}"

    log_info "Skapar VM: $name"
    echo "  Memory: $memory"
    echo "  Disk:   $disk"
    echo "  CPUs:   $cpus"
    echo ""

    # Skapa cloud-init för SSH-nyckel och grundsetup
    local cloud_init
    cloud_init=$(mktemp)

    cat > "$cloud_init" << 'EOF'
#cloud-config
package_update: true
packages:
  - git
  - curl
  - htop
  - vim

# Tillåt lösenordslös sudo
runcmd:
  - echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/90-ubuntu-nopasswd
EOF

    # Lägg till SSH-nyckel om den finns
    if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
        log_info "Lägger till din SSH-nyckel..."
        {
            echo ""
            echo "ssh_authorized_keys:"
            echo "  - $(cat "$HOME/.ssh/id_rsa.pub")"
        } >> "$cloud_init"
    elif [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        log_info "Lägger till din SSH-nyckel (ed25519)..."
        {
            echo ""
            echo "ssh_authorized_keys:"
            echo "  - $(cat "$HOME/.ssh/id_ed25519.pub")"
        } >> "$cloud_init"
    else
        log_warn "Ingen SSH-nyckel hittades. Använd 'multipass shell' för åtkomst."
    fi

    # Skapa VM
    local bridge_opts=""
    if [[ $use_bridge -eq 1 ]]; then
        # Hitta nätverksinterface för bridge
        local interface
        interface=$(ip route | grep default | awk '{print $5}' | head -1)
        if [[ -n "$interface" ]]; then
            log_info "Använder bridge-nätverk på: $interface"
            bridge_opts="--network $interface"
        else
            log_warn "Kunde inte hitta nätverksinterface, skippar bridge"
        fi
    fi

    log_info "Startar VM (detta tar en stund första gången)..."
    # shellcheck disable=SC2086
    multipass launch "$DEFAULT_IMAGE" \
        --name "$name" \
        --memory "$memory" \
        --disk "$disk" \
        --cpus "$cpus" \
        --cloud-init "$cloud_init" \
        $bridge_opts

    rm -f "$cloud_init"

    # Vänta på att VM:en är redo
    wait_for_vm "$name"

    # Hämta IP
    local ip
    ip=$(get_vm_ip "$name")

    echo ""
    log_info "VM '$name' är redo!"
    echo ""
    echo "========================================"
    echo -e "  ${CYAN}IP-adress:${NC}  $ip"
    echo -e "  ${CYAN}Användare:${NC}  ubuntu"
    echo "========================================"
    echo ""
    echo "Anslut med:"
    echo "  multipass shell $name     # Snabbast"
    echo "  ssh ubuntu@$ip            # Med SSH"
    echo "  $0 ssh $name              # Genväg"
    echo ""
    echo "Testa dina scripts:"
    echo "  multipass shell $name"
    echo "  git clone https://github.com/Thomas-3145/homelab-infrastructure"
    echo "  cd homelab-infrastructure && ./scripts/01_setup.sh"
    echo ""
}

cmd_list() {
    log_info "Multipass VMs:"
    echo ""
    multipass list
}

cmd_shell() {
    local name="${1:-$DEFAULT_NAME}"
    multipass shell "$name"
}

cmd_ssh() {
    local name="${1:-$DEFAULT_NAME}"
    local ip
    ip=$(get_vm_ip "$name")

    if [[ -z "$ip" ]]; then
        log_error "Kunde inte hitta IP för '$name'"
        exit 1
    fi

    log_info "Ansluter till $name ($ip)..."
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "ubuntu@$ip"
}

cmd_delete() {
    local name="${1:-$DEFAULT_NAME}"

    log_warn "Detta kommer ta bort VM '$name' permanent!"
    read -rp "Är du säker? (y/N) " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Tar bort '$name'..."
        multipass delete "$name"
        multipass purge
        log_info "VM borttagen."
    else
        log_info "Avbrutet."
    fi
}

cmd_ip() {
    local name="${1:-$DEFAULT_NAME}"
    local ip
    ip=$(get_vm_ip "$name")

    if [[ -n "$ip" ]]; then
        echo "$ip"
    else
        log_error "Kunde inte hitta IP för '$name'"
        exit 1
    fi
}

# --- Main ---
main() {
    local command="${1:-}"

    if [[ -z "$command" ]]; then
        show_usage
        exit 0
    fi

    check_multipass

    case "$command" in
        create)
            shift
            cmd_create "$@"
            ;;
        list|ls)
            cmd_list
            ;;
        shell|sh)
            cmd_shell "${2:-}"
            ;;
        ssh)
            cmd_ssh "${2:-}"
            ;;
        delete|rm)
            cmd_delete "${2:-}"
            ;;
        ip)
            cmd_ip "${2:-}"
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
