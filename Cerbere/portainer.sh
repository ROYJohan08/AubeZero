#!/bin/bash
set -euo pipefail

Programme="Cerbere-Portainer"
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Variables par défaut === #
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

    # Télécharger la nouvelle image
    docker pull portainer/portainer-ce:latest >/dev/null 2>&1 \
        || { log "[-] Impossible de télécharger la nouvelle image"; exit 1; }

    # Supprimer l'ancien conteneur
    docker rm -f portainer >/dev/null 2>&1 || true
    log "[~] Ancien conteneur supprimé"

    # Re-créer Portainer avec les paramètres AubeZero
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
