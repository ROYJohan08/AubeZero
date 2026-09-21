#!/bin/sh
# Apollon - Home Assistant
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, gestion et conteneurisation du serveur Home Assistant pour AubeZero

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
DEFAULT_HA_PATH="$DEFAULT_DOCS01/HomeAssistant"

HA_DIR="${PATH_HOMEASSISTANT:-$DEFAULT_HA_PATH}"
TZ_ENV="${TZ:-Europe/Paris}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-APOLLON-HOMEASSISTANT.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Apollon-HomeAssistant"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Préparation du répertoire de travail ===
mkdir -p "$HA_DIR"

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

# === 6. Création / Recréation du conteneur Docker Home Assistant ===
create_ha_docker() {
    log "~" "Recréation du conteneur Docker Home Assistant..."

    docker rm -f homeassistant >/dev/null 2>&1 || true
    docker pull homeassistant/home-assistant:latest >/dev/null 2>&1

    # Construction dynamique des arguments optionnels de carte graphique
    DEVICE_ARG=""
    if [ -d "/dev/dri" ]; then
        DEVICE_ARG="--device /dev/dri:/dev/dri"
    fi

    if docker run -d \
        --name homeassistant \
        --restart=unless-stopped \
        --network=host \
        -e TZ="$TZ_ENV" \
        -v "$HA_DIR:/config" \
        -v /run/dbus:/run/dbus:ro \
        $DEVICE_ARG \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --cap-add NET_RAW \
        --cap-add NET_ADMIN \
        --cap-add NET_BIND_SERVICE \
        homeassistant/home-assistant:latest >/dev/null 2>&1; then
        log "+" "Conteneur Home Assistant créé et opérationnel"
    else
        log "[-]" "Échec de la création du conteneur Home Assistant"
        exit 1
    fi
}

create_ha_docker

# === 7. Génération de la commande CLI /usr/bin/homeassistant ===
install_ha_command() {
    log "~" "Création de la commande globale /usr/bin/homeassistant"

    HA_CMD="/usr/bin/homeassistant"

    cat << 'EOF' > "$HA_CMD"
#!/bin/sh
# Apollon - Home Assistant CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion du service Home Assistant

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-APOLLON-HOMEASSISTANT.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

DEFAULT_DOCS01="/media/Docs01"
DEFAULT_HA_PATH="$DEFAULT_DOCS01/HomeAssistant"

HA_DIR="${PATH_HOMEASSISTANT:-$DEFAULT_HA_PATH}"
TZ_ENV="${TZ:-Europe/Paris}"

create_docker() {
    log "~" "Recréation du conteneur Home Assistant..."
    docker rm -f homeassistant >/dev/null 2>&1 || true
    docker pull homeassistant/home-assistant:latest >/dev/null 2>&1

    DEVICE_ARG=""
    if [ -d "/dev/dri" ]; then
        DEVICE_ARG="--device /dev/dri:/dev/dri"
    fi

    if docker run -d \
        --name homeassistant \
        --restart=unless-stopped \
        --network=host \
        -e TZ="$TZ_ENV" \
        -v "$HA_DIR:/config" \
        -v /run/dbus:/run/dbus:ro \
        $DEVICE_ARG \
        --security-opt no-new-privileges:true \
        --cap-drop ALL \
        --cap-add NET_RAW \
        --cap-add NET_ADMIN \
        --cap-add NET_BIND_SERVICE \
        homeassistant/home-assistant:latest >/dev/null 2>&1; then
        log "+" "Conteneur Home Assistant recréé et opérationnel"
    else
        log "[-]" "Échec lors de la recréation du conteneur Home Assistant"
        exit 1
    fi
}

case "${1:-none}" in
    start)
        log "~" "Démarrage de Home Assistant"
        docker start homeassistant >/dev/null 2>&1 && log "+" "Home Assistant démarré"
        ;;
    stop)
        log "~" "Arrêt de Home Assistant"
        docker stop homeassistant >/dev/null 2>&1 && log "+" "Home Assistant arrêté"
        ;;
    restart)
        log "~" "Redémarrage de Home Assistant"
        docker restart homeassistant >/dev/null 2>&1 && log "+" "Home Assistant redémarré"
        ;;
    update)
        log "~" "Mise à jour de Home Assistant"
        create_docker
        ;;
    logs)
        docker logs -f homeassistant
        ;;
    *)
        echo "Usage : homeassistant {start|stop|restart|update|logs}"
        exit 1
        ;;
esac
EOF

    chmod +x "$HA_CMD"
    log "+" "Commande homeassistant installée : $HA_CMD"
}

install_ha_command

log "✓" "Module Apollon-HomeAssistant installé et opérationnel"
