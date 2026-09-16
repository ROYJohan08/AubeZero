#!/bin/bash
# apollon-kiwix.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:51
# @Desc : Installation, mise à jour et gestion du serveur Kiwix pour AubeZero

set -euo pipefail

Programme="Apollon-Kiwix"

# === Chargement credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_DOCS01="/media/Docs01"
DEFAULT_CERBERE="/etc/AubeZero/Cerbere"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_DOCS01="$DEFAULT_DOCS01"
    PATH_CERBERE="$DEFAULT_CERBERE"
    PORT_KIWIX="8080"
    PATH_KIWIX="/media/Docs01/Kiwix"
fi

# === LOG SYSTEM === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Début du module Kiwix"

# === Variables === #
JSON_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/main/Apollon/kiwix.json"
LOCAL_JSON="${PATH_CERBERE}/Apollon/kiwix.json"
TMP_JSON="/tmp/kiwix.json"
KIWIX_DIR="${PATH_KIWIX}"
KIWIX_PORT="${PORT_KIWIX}"

mkdir -p "$KIWIX_DIR"
mkdir -p "$(dirname "$LOCAL_JSON")"

# === Dépendances === #
check_dep() {
    if command -v "$1" >/dev/null 2>&1; then
        log "[=] Dépendance OK : $1"
        return
    fi

    log "[~] Installation dépendance : $1"
    apt-get update -qq
    apt-get install -y -qq "$1"
}

check_dep "curl"
check_dep "jq"
check_dep "docker"

# === Téléchargement JSON (avec fallback local) === #
log "[~] Téléchargement de kiwix.json"

if curl -sSL -f "$JSON_URL" -o "$TMP_JSON"; then
    log "[+] kiwix.json téléchargé"
    cp "$TMP_JSON" "$LOCAL_JSON"
else
    log "[−] Échec téléchargement kiwix.json — fallback local"
    if [[ ! -f "$LOCAL_JSON" ]]; then
        log "[−] Aucun JSON local disponible — arrêt"
        exit 1
    fi
    cp "$LOCAL_JSON" "$TMP_JSON"
fi

# === Téléchargement des fichiers ZIM === #
log "[~] Téléchargement des fichiers ZIM"

RSYNC_HOST="rsync://download.kiwix.org/zim/builds"

jq -r '.[]' "$TMP_JSON" | while read -r zim; do
    log "[~] Téléchargement : $zim"
    rsync -avP "$RSYNC_HOST/$zim" "$KIWIX_DIR/" >/dev/null 2>&1 \
        && log "[+] OK : $zim" \
        || log "[−] FAIL : $zim"
done

log "[+] Téléchargements ZIM terminés"

# === Création / Recréation du Docker Kiwix === #
create_kiwix_docker() {
    log "[~] Recréation du conteneur Kiwix"

    docker rm -f kiwix >/dev/null 2>&1 || true
    docker pull ghcr.io/kiwix/kiwix-serve:latest >/dev/null 2>&1

    docker run -d \
        --name kiwix \
        --restart unless-stopped \
        -p "${KIWIX_PORT}:8080" \
        -v "${KIWIX_DIR}:/data" \
        ghcr.io/kiwix/kiwix-serve:latest \
        /data/*.zim >/dev/null 2>&1

    log "[+] Conteneur Kiwix opérationnel"
}

create_kiwix_docker

# === Création de la commande kiwix === #
log "[~] Création de la commande kiwix"

KIWIX_CMD="/usr/bin/kiwix"

cat > "$KIWIX_CMD" << 'EOF'
#!/bin/bash
set -euo pipefail

Programme="Apollon-Kiwix"

# === Credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
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
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

KIWIX_DIR="${PATH_KIWIX:-/media/Docs01/Kiwix}"
KIWIX_PORT="${PORT_KIWIX:-8080}"

create_docker() {
    log "[~] Recréation du conteneur Kiwix"
    docker rm -f kiwix >/dev/null 2>&1 || true
    docker pull ghcr.io/kiwix/kiwix-serve:latest >/dev/null 2>&1

    docker run -d \
        --name kiwix \
        --restart unless-stopped \
        -p "${KIWIX_PORT}:8080" \
        -v "${KIWIX_DIR}:/data" \
        ghcr.io/kiwix/kiwix-serve:latest \
        /data/*.zim >/dev/null 2>&1

    log "[+] Conteneur Kiwix opérationnel"
}

case "$1" in
    start)
        log "[~] Démarrage Kiwix"
        docker start kiwix >/dev/null 2>&1 && log "[+] Kiwix démarré"
        ;;
    stop)
        log "[~] Arrêt Kiwix"
        docker stop kiwix >/dev/null 2>&1 && log "[+] Kiwix arrêté"
        ;;
    restart)
        log "[~] Redémarrage Kiwix"
        docker restart kiwix >/dev/null 2>&1 && log "[+] Kiwix redémarré"
        ;;
    update)
        log "[~] Mise à jour Kiwix"
        create_docker
        ;;
    *)
        echo "Usage : kiwix {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

chmod +x "$KIWIX_CMD"
log "[+] Commande kiwix installée : /usr/bin/kiwix"

# === Mise à jour du gestionnaire ZIM (kiwix.php) === #
log "[~] Vérification du gestionnaire ZIM kiwix.php"

REMOTE_KIWIX_PHP="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Apollon/kiwix.php"
LOCAL_KIWIX_PHP="${PATH_LAMP}/kiwix.php"
TMP_KIWIX_PHP="/tmp/kiwix.php"

mkdir -p "$(dirname "$LOCAL_KIWIX_PHP")"

# Téléchargement temporaire
if curl -sSL -f "$REMOTE_KIWIX_PHP" -o "$TMP_KIWIX_PHP"; then
    log "[+] kiwix.php téléchargé temporairement"
else
    log "[−] Impossible de télécharger kiwix.php — abandon de la mise à jour"
    rm -f "$TMP_KIWIX_PHP"
    exit 0
fi

# Si le fichier local n'existe pas → installation directe
if [[ ! -f "$LOCAL_KIWIX_PHP" ]]; then
    cp "$TMP_KIWIX_PHP" "$LOCAL_KIWIX_PHP"
    chmod 644 "$LOCAL_KIWIX_PHP"
    log "[+] kiwix.php installé (nouvelle installation)"
    rm -f "$TMP_KIWIX_PHP"
    exit 0
fi

# Comparaison des versions (hash)
LOCAL_HASH=$(sha256sum "$LOCAL_KIWIX_PHP" | awk '{print $1}')
REMOTE_HASH=$(sha256sum "$TMP_KIWIX_PHP" | awk '{print $1}')

if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
    cp "$TMP_KIWIX_PHP" "$LOCAL_KIWIX_PHP"
    chmod 644 "$LOCAL_KIWIX_PHP"
    log "[+] kiwix.php mis à jour (version distante plus récente)"
else
    log "[=] kiwix.php déjà à jour"
fi

rm -f "$TMP_KIWIX_PHP"

log "[✓] Module Kiwix installé et opérationnel"
