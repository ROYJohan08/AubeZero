#!/bin/bash
# cerbere-portainer.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:42
# @Desc : Installation de la commande Portainer pour AubeZero + gestion du conteneur

set -euo pipefail

# === Chargement des credentials === #
CREDENTIALS_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"

if [[ -f "$CREDENTIALS_FILE" ]]; then
    set -a
    source "$CREDENTIALS_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
fi

# === LOG SYSTEM === #
Programme="Cerbere-Portainer"

if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Installation de la commande Portainer"

# === Variables par défaut === #
PORTAINER_PORT="${PORT_PORTAINER:-1005}"
PORTAINER_CONFIG="${PATH_PORTAINER_CONFIG:-/media/Runable/Docker/Portainer}"

# === Création de la commande /usr/local/bin/portainer === #
COMMAND_PATH="/usr/local/bin/portainer"

log "[~] Génération de la commande Portainer"

cat << 'EOF' > "$COMMAND_PATH"
#!/bin/bash
set -euo pipefail

Programme="Cerbere-Portainer"

# === Chargement des credentials === #
CREDENTIALS_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"

if [[ -f "$CREDENTIALS_FILE" ]]; then
    set -a
    source "$CREDENTIALS_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
fi

# === LOG SYSTEM === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Variables === #
PORTAINER_PORT="${PORT_PORTAINER:-1005}"
PORTAINER_CONFIG="${PATH_PORTAINER_CONFIG:-/media/Runable/Docker/Portainer}"

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

    docker pull portainer/portainer-ce:latest >/dev/null 2>&1 \
        || { log "[-] Impossible de télécharger la nouvelle image"; exit 1; }

    docker rm -f portainer >/dev/null 2>&1 || true
    log "[~] Ancien conteneur supprimé"

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
        || { log "[-] Impossible de recréer Portainer"; exit 1; }

    log "[+] Portainer mis à jour et recréé"
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
log "[+] Commande Portainer installée : /usr/local/bin/portainer"

log "[✓] Installation Cerbere-Portainer terminée"
