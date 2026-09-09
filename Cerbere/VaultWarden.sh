#!/bin/bash
# Author   : ROYJohan
# Version  : 1.0.1
# Date     : 2609082025

exec 1>/dev/null # Disable print unless errors
set -euo pipefail # Stop on errors

# --- Vérification des droits ---
if [ "$EUID" -ne 0 ]; then
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# --- Fonction de log ---
log() {
    Programme="Cerbere-VaultWarden"
    mkdir -p "/etc/AubeZero/Mnemosyne/" > /dev/null
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "/etc/AubeZero/Mnemosyne/$(date +%Y-%m).log"
}

# --- Vérification fichier credentials ---
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.sh"
if [[ ! -f "$CRED_FILE" ]]; then
    log "[-] Le fichier $CRED_FILE est introuvable."
    exit 1
fi

# --- Vérification variables requises ---
missing_vars=0
grep -qE '^[[:space:]]*PortVaultwarden=' "$CRED_FILE" || { log "[-] Variable PortVaultwarden absente du fichier."; missing_vars=1; }
grep -qE '^[[:space:]]*PathVaultWarden=' "$CRED_FILE" || { log "[-] Variable PathVaultWarden absente du fichier."; missing_vars=1; }
grep -qE '^[[:space:]]*PublicDns=' "$CRED_FILE" || { log "[-] Variable PublicDns absente du fichier."; missing_vars=1; }

if [[ "$missing_vars" -ne 0 ]]; then
    exit 1
fi

source "$CRED_FILE"

# --- Vérification Docker ---
if ! command -v docker >/dev/null 2>&1; then
    log "[~] Docker n'est pas installé. Installation en cours..."
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    log "[+] Docker installé."
fi

if ! docker info >/dev/null 2>&1; then
    log "[~] Docker installé mais ne répond pas. Redémarrage..."
    sudo systemctl restart docker
    sleep 2
    if ! docker info >/dev/null 2>&1; then
        log "[-] Docker ne répond toujours pas après redémarrage."
        exit 1
    fi
    log "[+] Docker fonctionne après redémarrage."
else
    log "[+] Docker est opérationnel."
fi

# --- Vérification port ---
if ss -tuln | grep -q ":${PortVaultwarden}"; then
    log "[-] Le port $PortVaultwarden est déjà utilisé."
    exit 1
fi

# --- Vérification dossier data ---
if [[ ! -d "$PathVaultWarden" ]]; then
    log "[-] Le chemin $PathVaultWarden n'existe pas."
    exit 1
fi

# --- SSL : création + vérification ---
sudo mkdir -p "$PathVaultWarden/ssl"

SSL_KEY="$PathVaultWarden/ssl/filename.key"
SSL_CRT="$PathVaultWarden/ssl/filename.crt"

if [[ -f "$SSL_KEY" || -f "$SSL_CRT" ]]; then
    log "[-] Certificat SSL déjà présent : $SSL_KEY ou $SSL_CRT"
else
    log "[~] Aucun certificat SSL trouvé. Génération en cours..."

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SSL_KEY" \
        -out "$SSL_CRT" \
        -subj "/CN=$PublicDns"

    if [[ -f "$SSL_KEY" && -f "$SSL_CRT" ]]; then
        log "[+] Certificat SSL généré avec succès."
    else
        log "[-] Échec de la génération du certificat SSL."
        exit 1
    fi
fi

# --- Déploiement Vaultwarden ---
sudo docker rm -f vaultwarden >/dev/null 2>&1 || true
sudo docker pull vaultwarden/server:latest

sudo docker run -d \
    --name vaultwarden \
    -e ROCKET_TLS="{certs=\"/data/ssl/filename.crt\",key=\"/data/ssl/filename.key\"}" \
    -e WEBSOCKET_ENABLED=true \
    -v "$PathVaultWarden":/data \
    -p "$PortVaultwarden":80 \
    -p 3012:3012 \
    --restart unless-stopped \
    vaultwarden/server:latest

log "[+] Vaultwarden démarré"
