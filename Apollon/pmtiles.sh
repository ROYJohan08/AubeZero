#!/bin/sh
# Apollon - PMTiles
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, mise à jour de PMTiles et téléchargement de la carte de l'Europe

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

PATH_DOCS01="${PATH_DOCS01:-$DEFAULT_DOCS01}"
MAP_DIR="$PATH_DOCS01/Maps"
PMTILES_FILE="$MAP_DIR/Europa.pmtiles"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-APOLLON-PMTILES.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Apollon-PMTiles"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Préparation du répertoire de stockage ===
mkdir -p "$MAP_DIR"

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

# === 6. Vérification de la version locale ===
if command -v pmtiles >/dev/null 2>&1; then
    LOCAL_VERSION=$(pmtiles version 2>/dev/null | awk '{print $NF}' || echo "0")
    log "=" "Version locale de PMTiles : $LOCAL_VERSION"
else
    LOCAL_VERSION="0"
    log "~" "PMTiles est absent du système"
fi

# === 7. Vérification de la dernière version distante GitHub ===
log "~" "Recherche de la dernière version sur GitHub..."

GITHUB_RELEASE=$(curl -sSL -f https://api.github.com/repos/protomaps/PMTiles/releases/latest 2>/dev/null || true)

if [ -n "$GITHUB_RELEASE" ]; then
    GITHUB_VERSION=$(echo "$GITHUB_RELEASE" | jq -r '.tag_name // empty' | sed 's/^v//')
else
    GITHUB_VERSION=""
fi

if [ -z "$GITHUB_VERSION" ]; then
    log "[-]" "Impossible de récupérer la version GitHub (hors-ligne ?)"
    GITHUB_VERSION="$LOCAL_VERSION"
else
    log "+" "Dernière version GitHub trouvée : $GITHUB_VERSION"
fi

# === 8. Installation ou mise à jour du binaire PMTiles ===
if [ "$LOCAL_VERSION" != "$GITHUB_VERSION" ] && [ "$GITHUB_VERSION" != "0" ]; then
    log "~" "Installation de PMTiles v${GITHUB_VERSION}..."

    PMTILES_BIN="/usr/bin/pmtiles"
    
    if curl -sSL -f "https://github.com/protomaps/PMTiles/releases/download/v${GITHUB_VERSION}/pmtiles-linux-amd64" -o "$PMTILES_BIN"; then
        chmod +x "$PMTILES_BIN"
        log "+" "PMTiles mis à jour avec succès (v${GITHUB_VERSION})"
    else
        log "[-]" "Échec du téléchargement du binaire PMTiles"
    fi
else
    log "=" "PMTiles est déjà à jour (v${LOCAL_VERSION})"
fi

# === 9. Téléchargement de la carte de l'Europe ===
if [ -f "$PMTILES_FILE" ]; then
    log "=" "Fichier Europa.pmtiles déjà présent : $PMTILES_FILE"
else
    log "~" "Téléchargement de la carte Europa.pmtiles..."

    if curl -sSL -f "https://build.protomaps.com/2024/europe.pmtiles" -o "$PMTILES_FILE"; then
        log "+" "Téléchargement de Europa.pmtiles terminé"
    else
        log "[-]" "Échec du téléchargement de la carte Europa.pmtiles"
        rm -f "$PMTILES_FILE"
    fi
fi

log "✓" "Module Apollon-PMTiles installé et opérationnel"
