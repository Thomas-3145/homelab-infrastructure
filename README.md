[![CI - Code Quality](https://github.com/Thomas-3145/homelab-infrastructure/actions/workflows/ci.yml/badge.svg)](https://github.com/Thomas-3145/homelab-infrastructure/actions/workflows/ci.yml) ![Runner](https://img.shields.io/badge/Runner-Self--Hosted-blue?style=flat&logo=githubactions&logoColor=white)

# 🏡 HomeLab Infrastructure

Detta repo innehåller "Infrastructure as Code" (IaC) för min privata hemmaserver.
Syftet med projektet är att automatisera drift, övervakning och nätverkssäkerhet i hemmamiljön, samt att simulera en produktionsliknande miljö för lärande inom DevOps.

## 🛠 Teknisk Stack

* **OS:** Ubuntu Server 22.04 (LTS)
* **Container Runtime:** Docker & Docker Compose
* **Management UI:** Dockge (File-based Compose management)
* **CI/CD:** GitHub Actions (Self-hosted runner på servern)
* **Övervakning:** Prometheus & Grafana + Uptime Kuma

## 📂 Struktur

Projektet är uppdelat i moduler baserat på funktion:

* `docker/adguard` - **DNS & Nätverkssäkerhet** (AdGuard Home)
* `docker/monitoring` - **Observability** (Prometheus, Grafana, Watchtower)
* `docker/vaultwarden` - **Password Management** (Bitwarden implementation)
* `docker/dockge` - **Stack Management** (IaC Dashboard)

## 🔐 Säkerhet & Hantering

* **Hemligheter:** Hanteras via `.env`-filer (i Dockge) som exkluderas via `.gitignore`.
* **Data:** All persistent data lagras i Docker Volumes eller specifika mappar som inte versionshanteras.
* **Uppdateringar:** Automatiserade via Watchtower (med label-baserad styrning) samt manuell hantering via Dockge.

## 🚀 Automation

Repo:t är kopplat till servern via en **GitHub Action (Self-hosted Runner)**.
När kod pushas till `main`, kan servern automatiskt validera och uppdatera konfigurationen, vilket säkerställer att det som finns i repot alltid matchar det som körs på servern (Single Source of Truth).
