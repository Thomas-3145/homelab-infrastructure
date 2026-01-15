# Security Documentation

## 🛡️ Security Philosophy
This infrastructure follows a "Defense in Depth" approach, utilizing network segmentation (Tailscale), system hardening (UFW/Fail2Ban), and continuous monitoring (Prometheus/Grafana/Uptime Kuma).

## 🔒 Network Security

### SSH Hardening
- **Custom Port:** SSH is moved from port 22 to **22456** (defined in `02_hardening.sh`).
- **Access:** Protected by Fail2Ban and UFW.
- **Root Login:** Disabled.
- **Authentication:** Key-based authentication recommended.

### Firewall (UFW)
The firewall is configured to `default deny incoming` and explicitly allows only necessary services:
- **Management:** SSH (22456/tcp), Dockge (5001/tcp)
- **Monitoring:** Uptime Kuma (3001/tcp), Grafana (3010/tcp), Prometheus (9090/tcp)
- **Services:** AdGuard Home (53/udp/tcp, 80/tcp, 443/tcp), Vaultwarden (8001/tcp)
- **VPN:** Tailscale (41641/udp)

### Tailscale VPN
- Acts as the primary secure gateway for remote access.
- **MagicDNS:** Enabled for internal service resolution.
- Services are primarily accessed via Tailscale IP (`100.x.x.x`) or local LAN (`192.168.x.x`).

## 🧱 System Hardening

### Fail2Ban
- **SSH Jail:** customized to monitor port 22456.
- **Policy:** 5 failed attempts = 1 hour ban.
- **Backend:** `systemd` monitoring enabled.

### User Permissions
- Docker runs in "Rootless mode" capability (user added to docker group).
- Administrative scripts check for `sudo` requirements but avoid running entirely as root.

## 🐳 Application Security

### Dockge (Management)
- Replaces Portainer as the GitOps-based container manager.
- **Volume Isolation:** Stacks are isolated in `~/homelab-infrastructure/docker/`.
- **Authentication:** Protected by strong password login.

### Watchtower (Automation)
- Automatically checks for container updates once every 24h (or at startup).
- Ensures security patches in images are applied promptly.
- Configured to clean up old images to prevent disk exhaustion.

### Vaultwarden
- **Data Protection:** Database is volume-mapped for easy backup.
- **Access:** Strictly exposed via internal network/Tailscale (no public port forwarding).
- **Backups:** Included in the `10_backup.sh` routine.

## 👁️ Monitoring & Observability

### The Monitoring Stack
Instead of manual log checking, the system is continuously monitored:
1.  **Prometheus:** Collects metrics from the host (Node Exporter) and containers (cAdvisor).
2.  **Grafana:** Visualizes metrics (CPU, RAM, Disk, Network traffic).
3.  **Uptime Kuma:** Active probing of service availability (HTTP/TCP checks).
    * Alerts if services go down.
    * Monitors internal Docker network via `host.docker.internal`.

### Health Checks
- **Automated Script:** `scripts/12_health_check.py` provides an instant snapshot of:
    - System temperatures (Pi 5).
    - Disk & RAM usage.
    - Docker container status.
    - Service endpoint availability.

## 🛠️ Maintenance & Operations

### Updates
Updates are handled via the `scripts/11_update.sh` script:
1.  **OS Level:** `apt update && apt upgrade`.
2.  **Infrastructure:** `git pull` to fetch latest repo changes.
3.  **Containers:** One-off Watchtower run.

### Backups
Backups are automated via `scripts/10_backup.sh`:
- **Strategy:** Stop containers -> Archive volumes/configs -> Restart containers.
- **Retention:** 7 days rolling backups.
- **Location:** `~/homelab-infrastructure/backups/`.

## 🚨 Incident Response

If a compromise is suspected:

1.  **Isolation:**
    ```bash
    sudo ufw default deny incoming
    sudo ufw reload
    sudo tailscale down
    ```
2.  **Investigation:**
    - Check active connections: `netstat -tunlp`
    - Review auth logs: `sudo grep "Failed password" /var/log/auth.log`
    - Check Docker logs: `docker compose logs --tail=100`
3.  **Restoration:**
    - Wipe affected stack.
    - Restore from last known good tarball in `./backups`.
    - Rotate SSH keys and passwords.
