#!/bin/bash
# apollon-standalone.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:48
# @Desc : Téléchargement, mise à jour et installation des logiciels standalone AubeZero

# === Vérification des droits administrateurs === #
if [ "$EUID" -ne 0 ]; then
    echo "[−] Droits insuffisants. Exécutez ce script en tant que root." >&2
    exit 1
fi

set -euo pipefail

Programme="Apollon-standalone"

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

log "[👉] Début"

# === Variables globales === #
JSON_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Apollon/standalone.json"
TARGET_DIR="${PATH_DOCS01}/Logiciels/StandaloneInstaller"
TMP_JSON="/tmp/StandAlone.json"
LOCAL_JSON="${PATH_CERBERE}/Apollon/standalone.json"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

mkdir -p "$TARGET_DIR"
mkdir -p "$(dirname "$LOCAL_JSON")"

# === Vérification et installation des dépendances === #
check_dep() {
    local dep="$1"
    local pkg_manager=""

    if command -v "$dep" >/dev/null 2>&1; then
        log "[=] Dépendance OK : $dep"
        return
    fi

    log "[~] Dépendance manquante : $dep | Installation"

    if command -v apt-get >/dev/null 2>&1; then pkg_manager="apt-get"
    elif command -v dnf >/dev/null 2>&1; then pkg_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then pkg_manager="yum"
    elif command -v pacman >/dev/null 2>&1; then pkg_manager="pacman"
    else
        log "[−] Aucun gestionnaire de paquets détecté"
        exit 1
    fi

    case "$pkg_manager" in
        apt-get)
            DEBIAN_FRONTEND=noninteractive apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$dep"
            ;;
        dnf) dnf install -y -q "$dep" ;;
        yum) yum install -y -q "$dep" ;;
        pacman) pacman -Sy --noconfirm --noprogressbar "$dep" ;;
    esac

    command -v "$dep" >/dev/null 2>&1 \
        && log "[+] Dépendance installée : $dep" \
        || { log "[−] Échec installation : $dep"; exit 1; }
}

log "[~] Vérification des dépendances"
check_dep "curl"
check_dep "jq"
log "[+] Dépendances OK"

# === Téléchargement JSON (avec fallback local) === #
log "[~] Téléchargement de la liste standalone"

if curl -sSL -f -A "$USER_AGENT" "$JSON_URL" -o "$TMP_JSON"; then
    log "[+] Téléchargement JSON : SUCCESS"
    cp "$TMP_JSON" "$LOCAL_JSON"
    log "[+] Copie locale mise à jour : $LOCAL_JSON"
else
    log "[−] Téléchargement JSON : FAIL — utilisation du JSON local"
    if [[ ! -f "$LOCAL_JSON" ]]; then
        log "[−] Aucun JSON local disponible — arrêt"
        exit 1
    fi
    cp "$LOCAL_JSON" "$TMP_JSON"
fi

# === Traitement des éléments === #
log "[~] Traitement de la liste"

IFS=$'\n'
jq -c '.[]' "$TMP_JSON" | while read -r item; do
    nom=$(echo "$item" | jq -r '.Nom // empty')
    version=$(echo "$item" | jq -r '.Version // empty')
    url=$(echo "$item" | jq -r '.Url // empty')

    if [[ -z "$url" || "$url" == "null" ]]; then
        log "[~] Élément ignoré (URL vide)"
        continue
    fi

    filename=$(basename "$url" | cut -d'?' -f1)

    if [[ -z "$filename" || "$filename" == *"="* || "$filename" == *"?"* ]]; then
        case "$version" in
            "Windows") filename="${nom}_Setup.exe" ;;
            "Mac")     filename="${nom}.dmg" ;;
            "Linux")   filename="${nom}.tar.gz" ;;
            "Android") filename="${nom}.apk" ;;
            *)         filename="${nom}_installer" ;;
        esac
    fi

    if [[ -n "$nom" && -n "$version" && "$version" != "null" ]]; then
        dest_dir="$TARGET_DIR/$nom/$version"
    else
        dest_dir="$TARGET_DIR/$nom"
    fi

    mkdir -p "$dest_dir"
    file_path="$dest_dir/$filename"

    log "[~] Téléchargement : $nom ($version)"

    if curl -sSL -A "$USER_AGENT" -L -z "$file_path" -o "$file_path" "$url"; then
        log "[+] Logiciel : $nom | Version : $version | Fichier : $file_path"
    else
        log "[−] Échec téléchargement : $nom | Version : $version"
    fi
done

rm -f "$TMP_JSON"
log "[+] Traitement terminé"

# === Ajout automatique de la tâche cron === #
CRON_CMD="bash /etc/AubeZero/Apollon/standalone.sh"
CRON_SCHEDULE="0 3 1-7 * 3"
CRON_LINE="$CRON_SCHEDULE $CRON_CMD"

log "[~] Vérification de la tâche cron"

if ! crontab -l 2>/dev/null | grep -F "$CRON_CMD" >/dev/null 2>&1; then
    (
        crontab -l 2>/dev/null
        echo "$CRON_LINE"
    ) | crontab -
    log "[+] Tâche cron ajoutée : $CRON_LINE"
else
    log "[=] Tâche cron déjà présente"
fi

# === Création de la commande standalone === #
log "[~] Création de la commande standalone"

STANDALONE_CMD="/usr/bin/standalone"

cat > "$STANDALONE_CMD" << 'EOF'
#!/bin/bash
set -euo pipefail

Programme="Apollon-Standalone"

# === Chargement credentials === #
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
    echo "$(date +'%Y%m%d%H%M')-Standalone-$1" >> "$LOG_FILE"
}

SCRIPT="/etc/AubeZero/Apollon/standalone.sh"

case "$1" in
    start)
        log "[~] Démarrage du module standalone"
        if pgrep -f "$SCRIPT" >/dev/null 2>&1; then
            log "[=] Module déjà en cours d'exécution"
            echo "[=] Apollon-standalone déjà démarré."
            exit 0
        fi
        bash "$SCRIPT" &
        log "[+] Module démarré"
        echo "[+] Apollon-standalone démarré."
        ;;

    stop)
        log "[~] Arrêt du module standalone"
        pkill -f "$SCRIPT" >/dev/null 2>&1 || true
        log "[+] Module arrêté"
        echo "[+] Apollon-standalone arrêté."
        ;;

    restart)
        log "[~] Redémarrage du module standalone"
        pkill -f "$SCRIPT" >/dev/null 2>&1 || true
        bash "$SCRIPT" &
        log "[+] Module redémarré"
        echo "[+] Apollon-standalone redémarré."
        ;;

    update)
        log "[~] Mise à jour du module standalone"
        bash "$SCRIPT"
        log "[+] Mise à jour complète"
        echo "[+] Mise à jour complète effectuée."
        ;;

    *)
        echo "[−] Action inconnue : $1"
        echo "Usage : standalone {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

chmod +x "$STANDALONE_CMD"
log "[+] Commande standalone créée : $STANDALONE_CMD"

log "[✓] Fin du programme"
