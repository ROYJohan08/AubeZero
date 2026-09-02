#!/bin/bash
Programme="Apollon-standalone"

# === Vérification des droits administrateurs === #
if [[ $EUID -ne 0 ]]; then
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# === Stop en cas d'erreurs === #
set -euo pipefail

# === Fonction de log === #
log() {
    local LOG_DIR="/etc/AubeZero/Mnemosyne"
    local LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
    mkdir -p "$LOG_DIR" >/dev/null 2>&1
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Variables === #
JSON_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Apollon/StandAlone.json"
TARGET_DIR="/media/Docs01/Logiciels/StandaloneInstaller"
TMP_JSON="/tmp/StandAlone.json"

mkdir -p "$TARGET_DIR"

# === Téléchargement JSON === #
log "Téléchargement de la lite : PENDING"
if ! curl -sSL -f "$JSON_URL" -o "$TMP_JSON"; then
    log "Téléchargement de la lite : FAIL"
    exit 1
fi
log "Téléchargement de la lite : SUCCESS"

# === Traitement JSON === #
log "Traitement de la liste : PENDING"

jq -c '.[]' "$TMP_JSON" | while read -r item; do
    nom=$(jq -r '.Nom // empty' <<< "$item")
    version=$(jq -r '.Version // empty' <<< "$item")
    url=$(jq -r '.Url // empty' <<< "$item")

    # Skip si URL absente
    [[ -z "$url" || "$url" == "null" ]] && continue

    filename=$(basename "$url" | cut -d'?' -f1)

    # Détermination du dossier de destination
    if [[ -n "$nom" && -n "$version" && "$version" != "null" ]]; then
        dest_dir="$TARGET_DIR/$nom/$version"
    elif [[ -n "$nom" ]]; then
        dest_dir="$TARGET_DIR/$nom"
    else
        dest_dir="$TARGET_DIR"
    fi

    mkdir -p "$dest_dir"

    file_path="$dest_dir/$filename"

    # Téléchargement conditionnel (-z = si fichier plus ancien)
    if curl -sSL -z "$file_path" -o "$file_path" "$url"; then
        if [[ -f "$file_path" ]]; then
            log "--> Logiciel : [$nom] | Version : [$version] | Fichier : $file_path"
        fi
    else
        log "--> Échec téléchargement : [$nom] | Version : [$version] | URL : $url"
    fi
done

rm -f "$TMP_JSON"
log "Traitement de la liste : SUCCESS"
