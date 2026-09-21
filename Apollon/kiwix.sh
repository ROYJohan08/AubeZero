#!/bin/sh
# Apollon - Kiwix
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, mise à jour et gestion du serveur Kiwix pour AubeZero

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
DEFAULT_CERBERE="$CERBERE_DIR"

PATH_DOCS01="${PATH_DOCS01:-$DEFAULT_DOCS01}"
PATH_CERBERE="${PATH_CERBERE:-$DEFAULT_CERBERE}"
KIWIX_PORT="${PORT_KIWIX:-8080}"
KIWIX_DIR="${PATH_KIWIX:-/media/Docs01/Kiwix}"
PATH_LAMP="${PATH_LAMP:-/var/www/html}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-APOLLON-KIWIX.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Apollon-Kiwix"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Variables de travail ===
JSON_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/main/Apollon/kiwix.json"
LOCAL_JSON="${PATH_CERBERE}/Apollon/kiwix.json"
TMP_JSON="/tmp/kiwix.json"

mkdir -p "$KIWIX_DIR"
mkdir -p "$(dirname "$LOCAL_JSON")"

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

check_dep "curl"
check_dep "jq"
check_dep "docker"
check_dep "rsync"

# === 6. Téléchargement du fichier kiwix.json ===
log "~" "Téléchargement de kiwix.json..."

if curl -sSL -f "$JSON_URL" -o "$TMP_JSON"; then
    log "+" "kiwix.json téléchargé avec succès"
    cp "$TMP_JSON" "$LOCAL_JSON"
else
    log "[-]" "Échec du téléchargement de kiwix.json — Bascule sur la version locale"
    if [ ! -f "$LOCAL_JSON" ]; then
        log "[-]" "Aucun fichier kiwix.json local disponible — Arrêt du processus"
        exit 1
    fi
    cp "$LOCAL_JSON" "$TMP_JSON"
fi

# === 7. Téléchargement des fichiers ZIM ===
log "~" "Téléchargement des fichiers ZIM..."

RSYNC_HOST="rsync://download.kiwix.org/zim/builds"

jq -r '.[]' "$TMP_JSON" | while read -r zim; do
    if [ -n "$zim" ]; then
        log "~" "Téléchargement ZIM : $zim"
        if rsync -avP "$RSYNC_HOST/$zim" "$KIWIX_DIR/" >/dev/null 2>&1; then
            log "+" "Téléchargement réussi : $zim"
        else
            log "[-]" "Échec du téléchargement : $zim"
        fi
    fi
done

log "+" "Téléchargements des fichiers ZIM terminés"

# === 8. Création / Recréation du conteneur Kiwix ===
create_kiwix_docker() {
    log "~" "Recréation du conteneur Docker Kiwix..."

    docker rm -f kiwix >/dev/null 2>&1 || true
    docker pull ghcr.io/kiwix/kiwix-serve:latest >/dev/null 2>&1

    if docker run -d \
        --name kiwix \
        --restart unless-stopped \
        -p "${KIWIX_PORT}:8080" \
        -v "${KIWIX_DIR}:/data" \
        ghcr.io/kiwix/kiwix-serve:latest \
        /data/*.zim >/dev/null 2>&1; then
        log "+" "Conteneur Kiwix créé et opérationnel"
    else
        log "[-]" "Échec lors de la création du conteneur Kiwix"
        exit 1
    fi
}

create_kiwix_docker

# === 9. Génération de la commande CLI /usr/bin/kiwix ===
install_kiwix_command() {
    log "~" "Création de la commande globale /usr/bin/kiwix"

    KIWIX_CMD="/usr/bin/kiwix"

    cat << 'EOF' > "$KIWIX_CMD"
#!/bin/sh
# Apollon - Kiwix CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion du serveur Kiwix

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-APOLLON-KIWIX.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

KIWIX_DIR="${PATH_KIWIX:-/media/Docs01/Kiwix}"
KIWIX_PORT="${PORT_KIWIX:-8080}"

create_docker() {
    log "~" "Recréation du conteneur Kiwix..."
    docker rm -f kiwix >/dev/null 2>&1 || true
    docker pull ghcr.io/kiwix/kiwix-serve:latest >/dev/null 2>&1

    if docker run -d \
        --name kiwix \
        --restart unless-stopped \
        -p "${KIWIX_PORT}:8080" \
        -v "${KIWIX_DIR}:/data" \
        ghcr.io/kiwix/kiwix-serve:latest \
        /data/*.zim >/dev/null 2>&1; then
        log "+" "Conteneur Kiwix recréé et opérationnel"
    else
        log "[-]" "Échec lors de la recréation du conteneur Kiwix"
        exit 1
    fi
}

case "${1:-none}" in
    start)
        log "~" "Démarrage du service Kiwix"
        docker start kiwix >/dev/null 2>&1 && log "+" "Kiwix démarré"
        ;;
    stop)
        log "~" "Arrêt du service Kiwix"
        docker stop kiwix >/dev/null 2>&1 && log "+" "Kiwix arrêté"
        ;;
    restart)
        log "~" "Redémarrage du service Kiwix"
        docker restart kiwix >/dev/null 2>&1 && log "+" "Kiwix redémarré"
        ;;
    update)
        log "~" "Mise à jour du service Kiwix"
        create_docker
        ;;
    *)
        echo "Usage : kiwix {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

    chmod +x "$KIWIX_CMD"
    log "+" "Commande kiwix installée : $KIWIX_CMD"
}

install_kiwix_command

# === 10. Mise à jour du gestionnaire ZIM (kiwix.php) ===
log "~" "Vérification du gestionnaire ZIM kiwix.php"

REMOTE_KIWIX_PHP="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Apollon/kiwix.php"
LOCAL_KIWIX_PHP="${PATH_LAMP}/kiwix.php"
TMP_KIWIX_PHP="/tmp/kiwix.php"

mkdir -p "$(dirname "$LOCAL_KIWIX_PHP")"

if curl -sSL -f "$REMOTE_KIWIX_PHP" -o "$TMP_KIWIX_PHP"; then
    log "+" "kiwix.php téléchargé temporairement"
else
    log "[-]" "Impossible de télécharger kiwix.php — Abandon de la mise à jour PHP"
    rm -f "$TMP_KIWIX_PHP"
    log "✓" "Module Apollon-Kiwix partiellement installé (sans la partie web PHP)"
    exit 0
fi

if [ ! -f "$LOCAL_KIWIX_PHP" ]; then
    cp "$TMP_KIWIX_PHP" "$LOCAL_KIWIX_PHP"
    chmod 644 "$LOCAL_KIWIX_PHP"
    log "+" "kiwix.php installé avec succès"
    rm -f "$TMP_KIWIX_PHP"
    log "✓" "Module Apollon-Kiwix installé et opérationnel"
    exit 0
fi

LOCAL_HASH=$(sha256sum "$LOCAL_KIWIX_PHP" | awk '{print $1}')
REMOTE_HASH=$(sha256sum "$TMP_KIWIX_PHP" | awk '{print $1}')

if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    cp "$TMP_KIWIX_PHP" "$LOCAL_KIWIX_PHP"
    chmod 644 "$LOCAL_KIWIX_PHP"
    log "+" "kiwix.php mis à jour vers la version distante"
else
    log "=" "kiwix.php est déjà à jour"
fi

rm -f "$TMP_KIWIX_PHP"

log "✓" "Module Apollon-Kiwix installé et opérationnel"
