import socket
import requests
import sys
import os

# --- HÄMTA HEMLIGHETER ---
# Vi försöker hämta porten från miljön.
# Om den saknas (t.ex. om du kör lokalt utan env) faller vi tillbaka på 22.
try:
    ssh_port_env = os.environ.get('SSH_PORT', '22')
    SSH_PORT = int(ssh_port_env) # Omvandla text till siffra
except ValueError:
    print("❌ Error: SSH_PORT environment variable must be a number.")
    sys.exit(1)

# --- KONFIGURATION ---
SERVICES = [
    # Här använder vi variabeln istället för att skriva 22456 direkt
    ("SSH Server", "tcp", "localhost", SSH_PORT),
    # ("AdGuard Home", "http", "http://localhost:3000", None),
]

def check_tcp_port(host, port):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception as e:
        return False

def check_http_url(url):
    try:
        response = requests.get(url, timeout=5)
        return 200 <= response.status_code < 300
    except:
        return False

def main():
    print(f"🏥 Starting Health Checks (Expecting SSH on port {SSH_PORT})...")
    all_passed = True

    for name, service_type, target, port in SERVICES:
        status = False
        
        if service_type == "tcp":
            status = check_tcp_port(target, port)
        elif service_type == "http":
            status = check_http_url(target)
            
        if status:
            print(f"✅ {name: <20} - UP")
        else:
            print(f"❌ {name: <20} - DOWN")
            all_passed = False

    if not all_passed:
        print("\nSome services are down!")
        sys.exit(1)
    else:
        print("\nAll systems operational! 🚀")
        sys.exit(0)

if __name__ == "__main__":
    main()
