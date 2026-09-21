#!/bin/sh
# Apollon - Standalone
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Téléchargement, mise à jour et installation des logiciels standalone AubeZero

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

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-APOLLON-STANDALONE.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Apollon-Standalone"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Variables globales ===
JSON_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Apollon/standalone.json"
TARGET_DIR="${PATH_DOCS01}/Logiciels/StandaloneInstaller"
TMP_JSON="/tmp/standalone.json"
LOCAL_JSON="${PATH_CERBERE}/Apollon/standalone.json"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

mkdir -p "$TARGET_DIR"
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

# === 6. Téléchargement du JSON (avec fallback local) ===
log "~" "Téléchargement de la liste des logiciels standalone..."

if curl -sSL -f -A "$USER_AGENT" "$JSON_URL" -o "$TMP_JSON"; then
    log "+" "Téléchargement JSON réussi"
    cp "$TMP_JSON" "$LOCAL_JSON"
    log "+" "Copie locale mise à jour : $LOCAL_JSON"
else
    log "[-]" "Échec du téléchargement JSON — Bascule sur la copie locale"
    if [ ! -f "$LOCAL_JSON" ]; then
        log "[-]" "Aucun fichier JSON local disponible — Arrêt du processus"
        exit 1
    fi
    cp "$LOCAL_JSON" "$TMP_JSON"
fi

# === 7. Traitement des logiciels ===
log "~" "Traitement de la liste..."

jq -c '.[]' "$TMP_JSON" | while read -r item; do
    nom=$(echo "$item" | jq -r '.Nom // empty')
    version=$(echo "$item" | jq -r '.Version // empty')
    url=$(echo "$item" | jq -r '.Url // empty')

    if [ -z "$url" ] || [ "$url" = "null" ]; then
        log "~" "Élément ignoré (URL manquante)"
        continue
    fi

    filename=$(basename "$url" | cut -d'?' -f1)

    case "$filename" in
        *=*|*\?*|"")
            case "$version" in
                "Windows") filename="${nom}_Setup.exe" ;;
                "Mac")     filename="${nom}.dmg" ;;
                "Linux")   filename="${nom}.tar.gz" ;;
                "Android") filename="${nom}.apk" ;;
                *)         filename="${nom}_installer" ;;
            esac
            ;;
    esac

    if [ -n "$nom" ] && [ -n "$version" ] && [ "$version" != "null" ]; then
        dest_dir="$TARGET_DIR/$nom/$version"
    else
        dest_dir="$TARGET_DIR/$nom"
    fi

    mkdir -p "$dest_dir"
    file_path="$dest_dir/$filename"

    log "~" "Téléchargement : $nom ($version)..."

    if curl -sSL -A "$USER_AGENT" -L -z "$file_path" -o "$file_path" "$url"; then
        log "+" "Logiciel $nom ($version) mis à jour dans $file_path"
    else
        log "[-]" "Échec du téléchargement de $nom ($version)"
    fi
done

rm -f "$TMP_JSON"

# === 8. Planification Cron ===
CRON_CMD="/bin/sh /etc/AubeZero/Apollon/standalone.sh"
CRON_SCHEDULE="0 3 1-7 * 3"
CRON_LINE="$CRON_SCHEDULE $CRON_CMD"

log "~" "Vérification de la tâche planifiée Cron..."

if ! crontab -l 2>/dev/null | grep -F "$CRON_CMD" >/dev/null 2>&1; then
    (
        crontab -l 2>/dev/null || true
        echo "$CRON_LINE"
    ) | crontab -
    log "+" "Tâche Cron ajoutée : $CRON_LINE"
else
    log "=" "Tâche Cron déjà présente"
fi

# === 9. Génération de la commande CLI /usr/bin/standalone ===
install_standalone_command() {
    log "~" "Création de la commande globale /usr/bin/standalone"

    STANDALONE_CMD="/usr/bin/standalone"

    cat << 'EOF' > "$STANDALONE_CMD"
#!/bin/sh
# Apollon - Standalone CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion des logiciels standalone

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-APOLLON-STANDALONE.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

SCRIPT="/etc/AubeZero/Apollon/standalone.sh"

case "${1:-none}" in
    start)
        log "~" "Démarrage du traitement standalone"
        if pgrep -f "$SCRIPT" >/dev/null 2>&1; then
            log "=" "Module standalone déjà en cours d'exécution"
            exit 0
        fi
        /bin/sh "$SCRIPT" &
        log "+" "Traitement standalone démarré en arrière-plan"
        ;;
    stop)
        log "~" "Arrêt du traitement standalone"
        pkill -f "$SCRIPT" >/dev/null 2>&1 || true
        log "+" "Traitement standalone arrêté"
        ;;
    restart)
        log "~" "Redémarrage du traitement standalone"
        pkill -f "$SCRIPT" >/dev/null 2>&1 || true
        /bin/sh "$SCRIPT" &
        log "+" "Traitement standalone redémarré"
        ;;
    update)
        log "~" "Exécution directe de la mise à jour standalone"
        /bin/sh "$SCRIPT"
        ;;
    *)
        echo "Usage : standalone {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

    chmod +x "$STANDALONE_CMD"
    log "+" "Commande standalone installée : $STANDALONE_CMD"
}

install_standalone_command

log "✓" "Module Apollon-Standalone installé et opérationnel"
