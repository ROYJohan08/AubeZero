#!/bin/sh
# Cerbere - SiYuan
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, gestion et sécurisation du serveur SiYuan pour AubeZero

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
DEFAULT_SIYUAN_PATH="/media/Docs01/SiYuan"
DEFAULT_SIYUAN_PORT="6806"

SIYUAN_DIR="${PATH_SIYUAN:-$DEFAULT_SIYUAN_PATH}"
SIYUAN_PORT="${PORT_SIYUAN:-$DEFAULT_SIYUAN_PORT}"
AUTH_CODE="${HIGH_PASSWORD:-changeme}"

USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-SIYUAN.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Cerbere-SiYuan"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Préparation du répertoire de travail ===
mkdir -p "$SIYUAN_DIR"

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

# === 6. Création / Recréation du conteneur Docker SiYuan ===
create_siyuan_docker() {
    log "~" "Recréation du conteneur SiYuan..."

    docker rm -f siyuan >/dev/null 2>&1 || true
    docker pull b3log/siyuan:latest >/dev/null 2>&1

    if docker run -d \
        --name siyuan \
        --restart unless-stopped \
        -v "${SIYUAN_DIR}:/siyuan/workspace" \
        -p "${SIYUAN_PORT}:6806" \
        -e PUID="${USER_ID}" \
        -e PGID="${GROUP_ID}" \
        b3log/siyuan:latest \
        serve \
        --workspace=/siyuan/workspace \
        --accessAuthCode="${AUTH_CODE}" >/dev/null 2>&1; then
        log "+" "Conteneur SiYuan créé et opérationnel"
    else
        log "[-]" "Échec lors de la création du conteneur SiYuan"
        exit 1
    fi
}

create_siyuan_docker

# === 7. Génération de la commande CLI /usr/bin/siyuan ===
install_siyuan_command() {
    log "~" "Création de la commande globale /usr/bin/siyuan"

    SIYUAN_CMD="/usr/bin/siyuan"

    cat << 'EOF' > "$SIYUAN_CMD"
#!/bin/sh
# Cerbere - SiYuan CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion du service SiYuan

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-SIYUAN.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

DEFAULT_SIYUAN_PATH="/media/Docs01/SiYuan"
DEFAULT_SIYUAN_PORT="6806"

SIYUAN_DIR="${PATH_SIYUAN:-$DEFAULT_SIYUAN_PATH}"
SIYUAN_PORT="${PORT_SIYUAN:-$DEFAULT_SIYUAN_PORT}"
AUTH_CODE="${HIGH_PASSWORD:-changeme}"

USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

create_docker() {
    log "~" "Recréation du conteneur SiYuan..."
    docker rm -f siyuan >/dev/null 2>&1 || true
    docker pull b3log/siyuan:latest >/dev/null 2>&1

    if docker run -d \
        --name siyuan \
        --restart unless-stopped \
        -v "${SIYUAN_DIR}:/siyuan/workspace" \
        -p "${SIYUAN_PORT}:6806" \
        -e PUID="${USER_ID}" \
        -e PGID="${GROUP_ID}" \
        b3log/siyuan:latest \
        serve \
        --workspace=/siyuan/workspace \
        --accessAuthCode="${AUTH_CODE}" >/dev/null 2>&1; then
        log "+" "Conteneur SiYuan recréé et opérationnel"
    else
        log "[-]" "Échec de la recréation du conteneur SiYuan"
        exit 1
    fi
}

case "${1:-none}" in
    start)
        log "~" "Démarrage du service SiYuan"
        docker start siyuan >/dev/null 2>&1 && log "+" "SiYuan démarré"
        ;;
    stop)
        log "~" "Arrêt du service SiYuan"
        docker stop siyuan >/dev/null 2>&1 && log "+" "SiYuan arrêté"
        ;;
    restart)
        log "~" "Redémarrage du service SiYuan"
        docker restart siyuan >/dev/null 2>&1 && log "+" "SiYuan redémarré"
        ;;
    update)
        log "~" "Mise à jour du service SiYuan"
        create_docker
        ;;
    *)
        echo "Usage : siyuan {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

    chmod +x "$SIYUAN_CMD"
    log "+" "Commande siyuan installée : $SIYUAN_CMD"
}

install_siyuan_command

log "✓" "Module Cerbere-SiYuan installé et opérationnel"
