#!/bin/bash
# Author   : ROYJohan
# Version  : 1.0.0
# Date     : 202609091047

exec 1>/dev/null # Disable print unless errors
set -euo pipefail # Stop on errors

# --- Vérification des droits ---
if [ "$EUID" -ne 0 ]; then
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# --- Fonction de log ---
log() {
    Programme="Cerbere-Credential"
    mkdir -p "/etc/AubeZero/Mnemosyne/" > /dev/null
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "/etc/AubeZero/Mnemosyne/$(date +%Y-%m).log"
}

# --- Vérification fichier credentials ---
CRED_FILE="/etc/AubeZero/Cerbere/Credentials_data.sh"
if [[ ! -f "$CRED_FILE" ]]; then
    log "[~] Le fichier $CRED_FILE est introuvable."

    RECENT_CREDENTIALS=$(find / -type f -name "credentials_data.sh" \
        -not -path "/proc/*" \
        -not -path "/sys/*" \
        -not -path "/dev/*" \
        -not -path "$CRED_FILE" \
        -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)

    if [[ -n "$RECENT_CREDENTIALS" && -f "$RECENT_CREDENTIALS" ]]; then
        cp "$RECENT_CREDENTIALS" "$CRED_FILE" > /dev/null
        log "[+] $CRED_FILE copié depuis $RECENT_CREDENTIALS"
    else
        log "[~] Le fichier $CRED_FILE est introuvable dans le système."

        if ! curl --fail --silent --show-error -o "$CRED_FILE" \
            "https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main/Cerbere/credentials_placeholder.sh"; then
            log "[-] Téléchargement depuis le net impossible"
            exit 1
        fi
    fi

    chown root:root "$CRED_FILE" > /dev/null
    chmod 700 "$CRED_FILE" > /dev/null

    if [[ -f "$CRED_FILE" ]]; then
        source "$CRED_FILE"
    else
        log "[-] Erreur étonnante, le fichier n'est pas là"
        exit 1
    fi

    log "[+] Credentials ok"
fi
