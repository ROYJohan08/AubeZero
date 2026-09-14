#!/bin/bash

exec 1>/dev/null
set -euo pipefail

# === LOG SYSTEM === #
Programme="Cerbere-Portainer"
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Début de l'installation de Portainer"

# === Vérification des droits === #
if [[ $EUID -ne 0 ]]; then
    log "[-] Ce script doit être exécuté en root"
    exit 1
fi
log "[+] Droits root confirmés"

# === Chargement des credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
    log "[~] credentials.env chargé"
else
    log "[-] credentials.env introuvable : arrêt"
    exit 1
fi

# === Variables avec fallback === #
PORTAINER_PORT="${PORT_PORTAINER:-1005}"
PORTAINER_CONFIG="${PATH_PORTAINER_CONFIG:-/media/Runable/Docker/Portainer}"

log "[+] Portainer port : $PORTAINER_PORT"
log "[+] Portainer config : $PORTAINER_CONFIG"

mkdir -p "$PORTAINER_CONFIG"

# === Installation Docker si absent === #
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[~] Docker absent : installation"

        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -y >/dev/null
            apt-get install -y ca-certificates curl gnupg lsb-release >/dev/null 2>&1
            install -m 0755 -d /etc/apt/keyrings >/dev/null
            curl -fsSL https://download.docker.com/linux/debian/gpg \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo \
              "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
              https://download.docker.com/linux/debian \
              $(lsb_release -cs) stable" \
              > /etc/apt/sources.list.d/docker.list
            apt-get update -y >/dev/null
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
        else
            log "[-] Impossible d’installer Docker : OS non supporté"
            exit 1
        fi

        log "[+] Docker installé"
    else
        log "[=] Docker déjà installé"
    fi
}

check_docker

# === Suppression ancienne instance === #
if docker ps -a --format '{{.Names}}' | grep -q "^portainer$"; then
    log "[~] Ancienne instance détectée : suppression"
    docker rm -f portainer >/dev/null 2>&1 || true
fi

# === Installation Portainer === #
log "[~] Téléchargement de Portainer"
docker pull portainer/portainer-ce:latest >/dev/null 2>&1 \
    || { log "[-] Impossible de télécharger Portainer"; exit 1; }

log "[~] Déploiement de Portainer"

docker run -d \
    --name portainer \
    --privileged \
    --restart unless-stopped \
    -e TZ=CET \
    -p 8000:8000 \
    -p 9443:9443 \
    -p "${PORTAINER_PORT}:9000" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v "${PORTAINER_CONFIG}:/data" \
    portainer/portainer-ce:latest \
    >/dev/null 2>&1 \
    || { log "[-] Impossible de lancer Portainer"; exit 1; }

log "[+] Portainer installé et démarré"

# === Installation de la commande portainer === #
COMMAND_PATH="/usr/local/bin/portainer"

log "[~] Installation de la commande portainer"

cat << 'EOF' > "$COMMAND_PATH"
#!/bin/bash
set -euo pipefail

Programme="Cerbere-Portainer"
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[-] Docker n'est pas installé"
        exit 1
    fi
}

start_portainer() {
    check_docker
    docker start portainer >/dev/null 2>&1 \
        && log "[+] Portainer démarré" \
        || log "[-] Impossible de démarrer Portainer"
}

stop_portainer() {
    check_docker
    docker stop portainer >/dev/null 2>&1 \
        && log "[+] Portainer arrêté" \
        || log "[-] Impossible d'arrêter Portainer"
}

restart_portainer() {
    check_docker
    docker restart portainer >/dev/null 2>&1 \
        && log "[+] Portainer redémarré" \
        || log "[-] Impossible de redémarrer Portainer"
}

update_portainer() {
    check_docker
    log "[~] Mise à jour Portainer..."
    docker pull portainer/portainer-ce:latest >/dev/null 2>&1
    docker rm -f portainer >/dev/null 2>&1 || true
    log "[+] Nouvelle image téléchargée"
}

status_portainer() {
    if docker ps | grep -q portainer; then
        log "[+] Portainer est en cours d'exécution"
        echo "Portainer est en cours d'exécution"
    else
        log "[~] Portainer est arrêté"
        echo "Portainer est arrêté"
    fi
}

case "${1:-none}" in
    start) start_portainer ;;
    stop) stop_portainer ;;
    restart) restart_portainer ;;
    update) update_portainer ;;
    status) status_portainer ;;
    *)
        echo "Usage : portainer {start|stop|restart|update|status}"
        exit 1
        ;;
esac
EOF

chmod +x "$COMMAND_PATH"
log "[+] Commande portainer installée"

# === Validation === #
if docker ps | grep -q portainer; then
    log "[✓] Installation et configuration de Portainer terminée"
else
    log "[-] Portainer ne s'exécute pas"
    exit 1
fi
