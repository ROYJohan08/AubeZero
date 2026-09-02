#!/bin/bash

# === Vérification des droits administrateurs === #
if [ "$EUID" -ne 0 ]; then
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# === Stop en cas d'erreurs globales === #
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

# === Vérification et installation des dépendances === #
check_dep() {
    local dep="$1"
    local start_time end_time duration
    local pkg_manager="unknown"

    if ! command -v "$dep" >/dev/null 2>&1; then
        log "Dépendance manquante : $dep | Installation : PENDING"

        # Détection du gestionnaire de paquets
        if command -v apt-get >/dev/null 2>&1; then
            pkg_manager="apt-get"
        elif command -v dnf >/dev/null 2>&1; then
            pkg_manager="dnf"
        elif command -v yum >/dev/null 2>&1; then
            pkg_manager="yum"
        elif command -v pacman >/dev/null 2>&1; then
            pkg_manager="pacman"
        else
            log "Installation impossible : gestionnaire de paquets non détecté"
            echo "Impossible d’installer automatiquement $dep" >&2
            exit 1
        fi

        log "Gestionnaire détecté : $pkg_manager | Dépendance : $dep"

        start_time=$(date +%s)

        # Installation silencieuse selon le gestionnaire
        case "$pkg_manager" in
            apt-get)
                DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null 2>&1
                DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$dep" >/dev/null 2>&1
                ;;
            dnf)
                dnf install -y -q "$dep" >/dev/null 2>&1
                ;;
            yum)
                yum install -y -q "$dep" >/dev/null 2>&1
                ;;
            pacman)
                pacman -Sy --noconfirm --noprogressbar "$dep" >/dev/null 2>&1
                ;;
        esac

        end_time=$(date +%s)
        duration=$((end_time - start_time))

        # Vérification post-installation
        if command -v "$dep" >/dev/null 2>&1; then
            log "Dépendance installée : $dep | SUCCESS | Durée=${duration}s | Gestionnaire=$pkg_manager"
        else
            log "Dépendance installée : $dep | FAIL | Durée=${duration}s | Gestionnaire=$pkg_manager"
            echo "Échec installation de $dep" >&2
            exit 1
        fi
    else
        log "Dépendance OK : $dep | Déjà installée"
    fi
}

# === Exécution de la vérification des dépendances === #
log "Vérification des dépendances : START"
check_dep "curl"
check_dep "jq"
log "Vérification des dépendances : COMPLETE"

# === Téléchargement de la base JSON === #
mkdir -p "$TARGET_DIR"

log "Téléchargement de la liste : PENDING"
if ! curl -sSL -f -A "$USER_AGENT" "$JSON_URL" -o "$TMP_JSON"; then
    log "Téléchargement de la liste : FAIL"
    exit 1
fi
log "Téléchargement de la liste : SUCCESS"

log "Traitement de la liste : PENDING"

# === Traitement des éléments === #
IFS=$'\n'
jq -c '.[]' "$TMP_JSON" | while read -r item; do
    nom=$(echo "$item" | jq -r '.Nom // empty')
    version=$(echo "$item" | jq -r '.Version // empty')
    url=$(echo "$item" | jq -r '.Url // empty')

    if [ -z "$url" ] || [ "$url" == "null" ]; then
        continue
    fi

    # Extraire le nom du fichier
    filename=$(basename "$url" | cut -d'?' -f1)

    # Fallback pour les URL dynamiques sans extension (ex: Firefox)
    if [ -z "$filename" ] || [[ "$filename" == *"="* ]] || [[ "$filename" == *"?"* ]]; then
        case "$version" in
            "Windows") filename="${nom}_Setup.exe" ;;
            "Mac")     filename="${nom}.dmg" ;;
            "Linux")   filename="${nom}.tar.gz" ;;
            "Android") filename="${nom}.apk" ;;
            *)         filename="${nom}_installer" ;;
        esac
    fi

    # Création du chemin cible
    if [ -n "$nom" ] && [ -n "$version" ] && [ "$version" != "null" ]; then
        dest_dir="$TARGET_DIR/$nom/$version"
    elif [ -n "$nom" ]; then
        dest_dir="$TARGET_DIR/$nom"
    else
        dest_dir="$TARGET_DIR"
    fi

    mkdir -p "$dest_dir"
    file_path="$dest_dir/$filename"

    # Téléchargement conditionnel (curl -z évite de retélécharger si le fichier n'a pas changé)
    if curl -sSL -A "$USER_AGENT" -L -z "$file_path" -o "$file_path" "$url"; then
        if [ -f "$file_path" ]; then
            log "--> Logiciel : [$nom] | Version : [$version] | Fichier : $file_path"
        fi
    else
        log "--> Échec téléchargement : [$nom] | Version : [$version] | URL : $url"
    fi
done

rm -f "$TMP_JSON"
log "Traitement de la liste : SUCCESS"
