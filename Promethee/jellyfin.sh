#!/bin/sh
# Promethee - Jellyfin
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, gestion et conteneurisation du serveur multimédia Jellyfin pour AubeZero

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

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# Valeurs par défaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
DEFAULT_DOCS01="/media/Docs01"
DEFAULT_RUNABLE="/media/Runable"

JELLYFIN_PORT="${PORT_JELLYFIN:-8096}"
JELLYFIN_CONFIG="${PATH_JELLYFIN_CONFIG:-$DEFAULT_DOCS01/Jellyfin/config}"
JELLYFIN_CACHE="${PATH_JELLYFIN_CACHE:-$DEFAULT_RUNABLE/Jellyfin/cache}"
JELLYFIN_MEDIA="${PATH_JELLYFIN_MEDIA:-/media}"
TZ_ENV="${TZ:-Europe/Paris}"

USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-PROMETHEE-JELLYFIN.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Promethee-Jellyfin"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Préparation des répertoires de travail ===
mkdir -p "$JELLYFIN_CONFIG"
mkdir -p "$JELLYFIN_CACHE"
mkdir -p "$JELLYFIN_MEDIA"

# === 5. Vérification des dépendances ===
check_dep() {
    _pkg="$1"
    if command -v "$_pkg" >/dev/null 2>&1; then
        log "=" "Dépendance OK : $_pkg"
        return 0
    fi

    log "~" "Installation de la dépendance : $_pkg"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq "$_pkg" >/dev/null 2>&1
    else
        log "[-]" "Gestionnaire de paquets non supporté pour installer $_pkg"
        exit 1
    fi
}

check_dep "docker"

# === 6. Création / Recréation du conteneur Docker Jellyfin ===
create_jellyfin_docker() {
    log "~" "Recréation du conteneur Docker Jellyfin..."

    docker rm -f jellyfin >/dev/null 2>&1 || true
    docker pull jellyfin/jellyfin:latest >/dev/null 2>&1

    # Prise en charge optionnelle de l'accélération matérielle
    DRI_ARG=""
    if [ -e "/dev/dri/renderD128" ]; then
        DRI_ARG="--device /dev/dri/renderD128:/dev/dri/renderD128"
    fi

    if docker run -d \
        --name jellyfin \
        --restart=unless-stopped \
        -e TZ="$TZ_ENV" \
        -e PUID="$USER_ID" \
        -e PGID="$GROUP_ID" \
        -p "${JELLYFIN_PORT}:8096" \
        -p 8920:8920 \
        -v "$JELLYFIN_CONFIG:/config" \
        -v "$JELLYFIN_CACHE:/cache" \
        -v "$JELLYFIN_MEDIA:/media:rw" \
        $DRI_ARG \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        jellyfin/jellyfin:latest >/dev/null 2>&1; then
        log "+" "Conteneur Jellyfin créé et opérationnel"
    else
        log "[-]" "Échec de la création du conteneur Jellyfin"
        exit 1
    fi
}

create_jellyfin_docker

# === 7. Génération de la commande CLI /usr/bin/jellyfin ===
install_jellyfin_command() {
    log "~" "Création de la commande globale /usr/bin/jellyfin"

    JELLYFIN_CMD="/usr/bin/jellyfin"

    cat << 'EOF' > "$JELLYFIN_CMD"
#!/bin/sh
# Promethee - Jellyfin CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion du service Jellyfin

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-PROMETHEE-JELLYFIN.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

DEFAULT_DOCS01="/media/Docs01"
DEFAULT_RUNABLE="/media/Runable"

JELLYFIN_PORT="${PORT_JELLYFIN:-8096}"
JELLYFIN_CONFIG="${PATH_JELLYFIN_CONFIG:-$DEFAULT_DOCS01/Jellyfin/config}"
JELLYFIN_CACHE="${PATH_JELLYFIN_CACHE:-$DEFAULT_RUNABLE/Jellyfin/cache}"
JELLYFIN_MEDIA="${PATH_JELLYFIN_MEDIA:-/media}"
TZ_ENV="${TZ:-Europe/Paris}"

USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

create_docker() {
    log "~" "Recréation du conteneur Jellyfin..."
    docker rm -f jellyfin >/dev/null 2>&1 || true
    docker pull jellyfin/jellyfin:latest >/dev/null 2>&1

    DRI_ARG=""
    if [ -e "/dev/dri/renderD128" ]; then
        DRI_ARG="--device /dev/dri/renderD128:/dev/dri/renderD128"
    fi

    if docker run -d \
        --name jellyfin \
        --restart=unless-stopped \
        -e TZ="$TZ_ENV" \
        -e PUID="$USER_ID" \
        -e PGID="$GROUP_ID" \
        -p "${JELLYFIN_PORT}:8096" \
        -p 8920:8920 \
        -v "$JELLYFIN_CONFIG:/config" \
        -v "$JELLYFIN_CACHE:/cache" \
        -v "$JELLYFIN_MEDIA:/media:rw" \
        $DRI_ARG \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        jellyfin/jellyfin:latest >/dev/null 2>&1; then
        log "+" "Conteneur Jellyfin recréé et opérationnel"
    else
        log "[-]" "Échec de la recréation du conteneur Jellyfin"
        exit 1
    fi
}

case "${1:-none}" in
    start)
        log "~" "Démarrage de Jellyfin"
        docker start jellyfin >/dev/null 2>&1 && log "+" "Jellyfin démarré"
        ;;
    stop)
        log "~" "Arrêt de Jellyfin"
        docker stop jellyfin >/dev/null 2>&1 && log "+" "Jellyfin arrêté"
        ;;
    restart)
        log "~" "Redémarrage de Jellyfin"
        docker restart jellyfin >/dev/null 2>&1 && log "+" "Jellyfin redémarré"
        ;;
    update)
        log "~" "Mise à jour de Jellyfin"
        create_docker
        ;;
    logs)
        docker logs -f jellyfin
        ;;
    *)
        echo "Usage : jellyfin {start|stop|restart|update|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x "$JELLYFIN_CMD"
    log "+" "Commande jellyfin installée : $JELLYFIN_CMD"
}

install_jellyfin_command

log "✓" "Module Promethee-Jellyfin installé et opérationnel"
