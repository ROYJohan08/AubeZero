#!/bin/bash

# === Vérification des droits administrateurs === #
if [ "$EUID" -ne 0 ]; then
    echo "[−] Droits insuffisants. Exécutez ce script en tant que root." >&2
    exit 1
fi

# === Stop en cas d'erreurs globales === #
set -euo pipefail

# === Variables globales === #
Programme="Apollon-standalone"
JSON_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Apollon/standalone.json"
TARGET_DIR="/media/Docs01/Logiciels/StandaloneInstaller"
TMP_JSON="/tmp/StandAlone.json"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# === Fonction de Logging === #
log() {
    LOG_DIR="/etc/AubeZero/Mnemosyne"
    LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Début"

# === Vérification et installation des dépendances === #
check_dep() {
    local dep="$1"
    local pkg_manager=""

    if command -v "$dep" >/dev/null 2>&1; then
        log "[=] Dépendance OK : $dep"
        return
    fi

    log "[~] Dépendance manquante : $dep | Installation"

    if command -v apt-get >/dev/null 2>&1; then
        pkg_manager="apt-get"
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
    elif command -v pacman >/dev/null 2>&1; then
        pkg_manager="pacman"
    else
        log "[−] Aucun gestionnaire de paquets détecté"
        echo "Impossible d’installer automatiquement $dep" >&2
        exit 1
    fi

    log "[~] Gestionnaire détecté : $pkg_manager"

    case "$pkg_manager" in
        apt-get)
            DEBIAN_FRONTEND=noninteractive apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$dep"
            ;;
        dnf)
            dnf install -y -q "$dep"
            ;;
        yum)
            yum install -y -q "$dep"
            ;;
        pacman)
            pacman -Sy --noconfirm --noprogressbar "$dep"
            ;;
    esac

    if command -v "$dep" >/dev/null 2>&1; then
        log "[+] Dépendance installée : $dep"
    else
        log "[−] Échec installation : $dep"
        exit 1
    fi
}

log "[~] Vérification des dépendances"
check_dep "curl"
check_dep "jq"
log "[+] Dépendances OK"

# === Téléchargement de la base JSON === #
mkdir -p "$TARGET_DIR"

log "[~] Téléchargement de la liste"
if ! curl -sSL -f -A "$USER_AGENT" "$JSON_URL" -o "$TMP_JSON"; then
    log "[−] Téléchargement JSON : FAIL"
    exit 1
fi
log "[+] Téléchargement JSON : SUCCESS"

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

if crontab -l 2>/dev/null | grep -F "$CRON_CMD" >/dev/null 2>&1; then
    log "[=] Tâche cron déjà présente : $CRON_CMD"
else
    log "[~] Ajout de la tâche cron"

    (
        crontab -l 2>/dev/null
        echo "$CRON_LINE"
    ) | crontab -

    if crontab -l 2>/dev/null | grep -F "$CRON_CMD" >/dev/null 2>&1; then
        log "[+] Tâche cron ajoutée : $CRON_LINE"
    else
        log "[−] Échec ajout tâche cron"
        exit 1
    fi
fi

log "[✓] Fin du programme"
