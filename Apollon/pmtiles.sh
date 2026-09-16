#!/usr/bin/env bash
set -euo pipefail

Programme="Apollon-PMTiles"
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"

# === Dossier de stockage === #
if [[ -z "${PATHDOCS01:-}" ]]; then
    PATHDOCS01="/media/Docs01"
fi

MAP_DIR="$PATHDOCS01/Maps"
PMTILES_FILE="$MAP_DIR/Europa.pmtiles"

# === Création des dossiers === #
mkdir -p "$LOG_DIR"
mkdir -p "$MAP_DIR"

log() {
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "Installation PMTiles : START"

# === Vérification installation locale === #
if command -v pmtiles >/dev/null 2>&1; then
    LOCAL_VERSION="$(pmtiles --version || echo "0")"
    log "PMTiles local : [=] Version $LOCAL_VERSION"
else
    LOCAL_VERSION="0"
    log "PMTiles local : ABSENT"
fi

# === Vérification version GitHub === #
GITHUB_VERSION="$(curl -s https://api.github.com/repos/protomaps/PMTiles/releases/latest | grep '"tag_name"' | cut -d '"' -f4 | sed 's/v//')"

if [[ -z "$GITHUB_VERSION" ]]; then
    log "Version GitHub : FAIL (offline ?)"
    GITHUB_VERSION="$LOCAL_VERSION"
else
    log "Version GitHub : $GITHUB_VERSION"
fi

# === Installation si version distante plus récente === #
if [[ "$LOCAL_VERSION" != "$GITHUB_VERSION" ]]; then
    log "Installation PMTiles : PENDING"

    curl -L "https://github.com/protomaps/PMTiles/releases/download/v${GITHUB_VERSION}/pmtiles-linux-amd64" \
        -o /usr/local/bin/pmtiles

    chmod +x /usr/local/bin/pmtiles

    log "Installation PMTiles : SUCCESS (v${GITHUB_VERSION})"
else
    log "Installation PMTiles : [=] Déjà à jour"
fi

# === Téléchargement de la carte Europe === #
if [[ -f "$PMTILES_FILE" ]]; then
    log "Europa.pmtiles : [=] Déjà présent"
else
    log "Europa.pmtiles : PENDING"

    curl -L "https://build.protomaps.com/2024/europe.pmtiles" -o "$PMTILES_FILE"

    log "Europa.pmtiles : SUCCESS"
fi

log "Installation PMTiles : END"

echo "PMTiles installé et carte Europe disponible."
