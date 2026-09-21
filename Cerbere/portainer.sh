#!/bin/sh
# Cerbere - Portainer
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation de la commande Portainer pour AubeZero et gestion du conteneur

# Stop en cas d'erreur ou de variable non definie
set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# === 2. Répertoires et configuration Cerbere ===
BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

mkdir -p "$CERBERE_DIR"

# Chargement dynamique du fichier credentials.env s'il existe
if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# Valeurs par défaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-PORTAINER.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Installation et configuration de la commande Portainer"

# Redirection de stdout globale vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Variables de configuration ===
PORTAINER_PORT="${PORT_PORTAINER:-1005}"
PORTAINER_CONFIG="${PATH_PORTAINER_CONFIG:-/media/Runable/Docker/Portainer}"
COMMAND_PATH="/usr/local/bin/portainer"

log "~" "Génération du wrapper CLI POSIX : $COMMAND_PATH"

# === 5. Génération de la commande /usr/local/bin/portainer ===
cat << 'EOF' > "$COMMAND_PATH"
#!/bin/sh
# Cerbere - Portainer CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Gestionnaire CLI du conteneur Portainer

set -eu

BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-PORTAINER.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

PORTAINER_PORT="${PORT_PORTAINER:-1005}"
PORTAINER_CONFIG="${PATH_PORTAINER_CONFIG:-/media/Runable/Docker/Portainer}"

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[-]" "Docker n'est pas installé ou introuvable"
        echo "[-] Erreur : Docker n'est pas disponible." >&2
        exit 1
    fi
}

start_portainer() {
    check_docker
    if docker start portainer >/dev/null 2>&1; then
        log "+" "Portainer démarré"
    else
        log "[-]" "Impossible de démarrer le conteneur Portainer"
    fi
}

stop_portainer() {
    check_docker
    if docker stop portainer >/dev/null 2>&1; then
        log "+" "Portainer arrêté"
    else
        log "[-]" "Impossible d'arrêter le conteneur Portainer"
    fi
}

restart_portainer() {
    check_docker
    if docker restart portainer >/dev/null 2>&1; then
        log "+" "Portainer redémarré"
    else
        log "[-]" "Impossible de redémarrer le conteneur Portainer"
    fi
}

update_portainer() {
    check_docker
    log "~" "Mise à jour de l'image Portainer..."

    if ! docker pull portainer/portainer-ce:latest >/dev/null 2>&1; then
        log "[-]" "Téléchargement de la nouvelle image Portainer échoué"
        exit 1
    fi

    docker rm -f portainer >/dev/null 2>&1 || true
    log "~" "Ancien conteneur Portainer supprimé"

    mkdir -p "$PORTAINER_CONFIG" >/dev/null 2>&1 || true

    if docker run -d \
        --name portainer \
        --privileged \
        --restart unless-stopped \
        -e TZ=CET \
        -p 8000:8000 \
        -p 9443:9443 \
        -p "${PORTAINER_PORT}:9000" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "${PORTAINER_CONFIG}:/data" \
        portainer/portainer-ce:latest >/dev/null 2>&1; then
        log "+" "Conteneur Portainer mis à jour et démarré avec succès"
    else
        log "[-]" "Échec de la récréation du conteneur Portainer"
        exit 1
    fi
}

status_portainer() {
    check_docker
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        log "=" "Portainer est en cours d'exécution"
        echo "Portainer est en cours d'exécution."
    else
        log "~" "Portainer est arrêté"
        echo "Portainer est arrêté."
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
log "+" "Commande exécutable Portainer installée : $COMMAND_PATH"

log "✓" "Installation de Cerbere-Portainer terminée avec succès"
