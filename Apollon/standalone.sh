#!/bin/bash

# === Vérification des droits administrateurs === #
if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# === Stop en cas d'erreurs d'exécution globale === #
set -euo pipefail

# === Variables globales === #
Programme="Apollon-standalone"
JSON_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Apollon/StandAlone.json"
TARGET_DIR="/media/Docs01/Logiciels/StandaloneInstaller"
TMP_JSON="/tmp/StandAlone.json"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

# === Fonction de Logging === #
log() {
    LOG_DIR="/etc/AubeZero/Mnemosyne"
    LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Initialisation === #
mkdir -p "$TARGET_DIR"

log "Téléchargement de la liste : PENDING"
if ! curl -sSL -f -A "$USER_AGENT" "$JSON_URL" -o "$TMP_JSON"; then
    log "Téléchargement de la liste : FAIL"
    exit 1
fi
log "Téléchargement de la liste : SUCCESS"

log "Traitement de la liste : PENDING"

IFS=$'\n'
jq -c '.[]' "$TMP_JSON" | while read -r item; do
    nom=$(echo "$item" | jq -r '.Nom // empty')
    version=$(echo "$item" | jq -r '.Version // empty')
    url=$(echo "$item" | jq -r '.Url // empty')

    if [ -z "$url" ] || [ "$url" == "null" ]; then
        continue
    fi

    # 1. Nettoyage du nom de fichier depuis l'URL
    filename=$(basename "$url" | cut -d'?' -f1)

    # 2. Gestion des URL dynamiques sans nom de fichier explicite (ex: Firefox)
    if [ -z "$filename" ] || [[ "$filename" == *"="* ]] || [[ "$filename" == *"?"* ]]; then
        case "$version" in
            "Windows") filename="${nom}_Setup.exe" ;;
            "Mac")     filename="${nom}.dmg" ;;
            "Linux")   filename="${nom}.tar.gz" ;;
            "Android") filename="${nom}.apk" ;;
            *)         filename="${nom}_installer" ;;
        esac
    fi

    # 3. Définition du dossier de destination
    if [ -n "$nom" ] && [ -n "$version" ] && [ "$version" != "null" ]; then
        dest_dir="$TARGET_DIR/$nom/$version"
    elif [ -n "$nom" ]; then
        dest_dir="$TARGET_DIR/$nom"
    else
        dest_dir="$TARGET_DIR"
    fi

    mkdir -p "$dest_dir"
    file_path="$dest_dir/$filename"

    # 4. Téléchargement sécurisé avec redirection (-L) et User-Agent (-A)
    if curl -sSL -A "$USER_AGENT" -z "$file_path" -o "$file_path" "$url"; then
        if [ -f "$file_path" ]; then
            log "--> Logiciel : [$nom] | Version : [$version] | Fichier : $file_path"
        fi
    else
        log "--> Échec téléchargement : [$nom] | Version : [$version] | URL : $url"
    fi
done

rm -f "$TMP_JSON"
log "Traitement de la liste : SUCCESS"
