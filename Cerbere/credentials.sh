#!/bin/bash
exec 1>/dev/null
set -euo pipefail

# --- Vérification des droits ---
if [[ "$EUID" -ne 0 ]]; then
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# --- Fonction de log ---
log() {
    local Programme="Cerbere-Credential"
    local LOG_DIR="/etc/AubeZero/Mnemosyne"
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "${LOG_DIR}/$(date +%Y-%m).log"
}

# --- Vérification fichier credentials ---
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"

if [[ ! -f "$CRED_FILE" ]]; then
    log "[~] Le fichier $CRED_FILE est introuvable."

    # Recherche du fichier le plus récent
    RECENT_CREDENTIALS=$(find / -type f -name "credentials.env" \
        -not -path "/proc/*" \
        -not -path "/sys/*" \
        -not -path "/dev/*" \
        -not -path "$CRED_FILE" \
        -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)

    if [[ -n "${RECENT_CREDENTIALS:-}" && -f "$RECENT_CREDENTIALS" ]]; then
        cp "$RECENT_CREDENTIALS" "$CRED_FILE"
        log "[+] $CRED_FILE copié depuis $RECENT_CREDENTIALS"
    else
        log "[~] Aucun credentials.env trouvé localement."

        # Téléchargement depuis GitHub
        if ! curl --fail --silent --show-error -o "$CRED_FILE" \
            "https://raw.githubusercontent.com/ROYJohan08/AubeZero/main/Cerbere/credentials.env"; then
            log "[-] Téléchargement impossible"
            exit 1
        fi
    fi

    # Permissions strictes
    chown root:root "$CRED_FILE"
    chmod 600 "$CRED_FILE"
fi

# --- Chargement du fichier local ---
if [[ -f "$CRED_FILE" ]]; then
    source "$CRED_FILE"
    log "[+] Credentials chargés"
else
    log "[-] Erreur : le fichier n'existe toujours pas après récupération."
    exit 1
fi

# --- Synchronisation avec GitHub : ajout des variables manquantes ---
log "[~] Vérification des variables manquantes via GitHub"
TMP_GITHUB="/tmp/credentials_github.env"
if curl --fail --silent --show-error \
    -o "$TMP_GITHUB" \
    "https://raw.githubusercontent.com/ROYJohan08/AubeZero/main/Cerbere/credentials.env"; then
    log "[+] Fichier GitHub récupéré pour comparaison"
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        var_name="${line%%=*}"
        if ! grep -q "^${var_name}=" "$CRED_FILE"; then
            echo "$line" >> "$CRED_FILE"
            log "[+] Variable ajoutée : $var_name"
        fi
    done < "$TMP_GITHUB"
    rm -f "$TMP_GITHUB"
    log "[+] Synchronisation terminée"
else
    log "[-] Impossible de récupérer le fichier GitHub pour synchronisation"
fi
