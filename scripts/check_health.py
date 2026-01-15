#!/usr/bin/env python3
import socket
import sys
import os
import shutil
import subprocess
import time

# Försök importera requests, annars ge ett tydligt felmeddelande
try:
    import requests
except ImportError:
    print("❌ Error: 'requests' module is missing.")
    print("   Install it with: sudo apt install python3-requests")
    sys.exit(1)

# --- KONFIGURATION ---
try:
    ssh_port_env = os.environ.get('SSH_PORT', '22456') # Din nya standardport
    SSH_PORT = int(ssh_port_env)
except ValueError:
    print("❌ Error: SSH_PORT environment variable must be a number.")
    sys.exit(1)

# Lista över tjänster att kolla
# Format: ("Namn", "Typ", "Adress", Port/None)
SERVICES = [
    ("SSH Server",    "tcp",  "localhost", SSH_PORT),
    ("AdGuard Home",  "http", "http://localhost:80", None),
    ("Grafana",       "http", "http://localhost:3010/login", None),
    ("Prometheus",    "http", "http://localhost:9090", None), # Grafana behöver inte /graph
    ("Uptime Kuma",   "http", "http://localhost:3001", None),
    ("Dockge",        "http", "http://localhost:5001", None),
]

# --- FUNKTIONER ---

def print_header(title):
    print(f"\n🔹 {title}")
    print("-" * 40)

def check_system_resources():
    print_header("System Resources")
    
    # 1. Diskutrymme (shutil är inbyggt i Python)
    total, used, free = shutil.disk_usage("/")
    # Konvertera bytes till GB
    gb = 1024 ** 3
    print(f"💾 Disk Usage: {used // gb} GB used / {total // gb} GB total")
    
    # 2. RAM (Vi läser /proc/meminfo för att slippa externa bibliotek)
    try:
        with open('/proc/meminfo', 'r') as mem:
            lines = mem.readlines()
        mem_total = int(lines[0].split()[1]) // 1024 # KB -> MB
        mem_free = int(lines[1].split()[1]) // 1024
        # Enkel uträkning (Total - Free är inte exakt 'Used' i Linux, men nära nog)
        print(f"🧠 RAM Total:  {mem_total} MB")
    except FileNotFoundError:
        print("🧠 RAM info:   Not available (Are you on Linux?)")

    # 3. Temperatur (Kör vcgencmd via subprocess om det finns)
    try:
        temp = subprocess.check_output(["vcgencmd", "measure_temp"], text=True).strip()
        print(f"🔥 CPU Temp:   {temp}")
    except (FileNotFoundError, subprocess.CalledProcessError):
        pass # Ignorera om kommandot inte finns (inte en Pi)

def check_docker_containers():
    print_header("Docker Containers")
    # Vi ber Python köra "docker ps" åt oss och skriva ut resultatet
    try:
        # custom-format för att göra det snyggt
        cmd = ["docker", "ps", "--format", "table {{.Names}}\t{{.Status}}\t{{.Ports}}"]
        result = subprocess.check_output(cmd, text=True)
        # Skriv ut varje rad med lite indrag
        for line in result.splitlines():
            print(f"   {line}")
    except FileNotFoundError:
        print("❌ Docker command not found.")
    except subprocess.CalledProcessError:
        print("❌ Failed to list Docker containers (Permission denied?)")

def check_tcp_port(host, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2) # Kortare timeout
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

def check_http_url(url):
    try:
        # Allow_redirects=True är default, men vi skriver ut det för tydlighet
        response = requests.get(url, timeout=3, allow_redirects=True)
        return 200 <= response.status_code < 300 or response.status_code == 401
        # Notera: 401 (Unauthorized) betyder att tjänsten lever men kräver inloggning. Det är OK!
    except:
        return False

# --- MAIN ---

def main():
    print("\n🏥 STARTING HOMELAB HEALTH CHECK 🏥")
    
    # Steg 1: Kolla hårdvara
    check_system_resources()
    
    # Steg 2: Kolla Docker
    check_docker_containers()
    
    # Steg 3: Kolla Tjänster
    print_header("Service Availability")
    all_passed = True

    for name, service_type, target, port in SERVICES:
        status = False
        
        if service_type == "tcp":
            status = check_tcp_port(target, port)
        elif service_type == "http":
            status = check_http_url(target)
            
        # Snyggare utskrift med emojis
        if status:
            print(f"✅ {name: <20} UP")
        else:
            print(f"❌ {name: <20} DOWN ({target})")
            all_passed = False

    print("\n" + "="*40)
    if not all_passed:
        print("⚠️  Some services are down check logs!")
        sys.exit(1)
    else:
        print("🚀 All systems operational!")
        sys.exit(0)

if __name__ == "__main__":
    main()
