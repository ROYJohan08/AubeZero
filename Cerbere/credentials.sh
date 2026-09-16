#!/bin/bash
exec 1>/dev/null
set -euo pipefail

# --- LOG ---
log() {
    local Programme="Cerbere-Credential"
    local LOG_DIR="/etc/AubeZero/Mnemosyne"
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "${LOG_DIR}/$(date +%Y-%m).log"
}

# --- DÉBUT ---
log "[👉] Début du programme"

# --- Vérification des droits ---
if [[ "$EUID" -ne 0 ]]; then
    log "[-] Droits insuffisants : exécution non-root"
    exit 1
fi
log "[+] Droits root confirmés"

# --- Dossiers nécessaires uniquement ---
mkdir -p "/etc/AubeZero/Cerbere"
mkdir -p "/etc/AubeZero/Mnemosyne"
log "[+] Dossiers essentiels vérifiés"

# --- Fichier credentials ---
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"

# --- Vérification existence credentials ---
if [[ ! -f "$CRED_FILE" ]]; then
    log "[~] Credentials introuvable : recherche locale"
    RECENT_CREDENTIALS=$(find / -type f -name "credentials.env" \
        -not -path "/proc/*" \
        -not -path "/sys/*" \
        -not -path "/dev/*" \
        -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
    if [[ -n "${RECENT_CREDENTIALS:-}" && -f "$RECENT_CREDENTIALS" ]]; then
        cp "$RECENT_CREDENTIALS" "$CRED_FILE"
        log "[+] Copie locale depuis $RECENT_CREDENTIALS"
    else
        log "[~] Aucun fichier local trouvé : tentative GitHub"
        if ! curl --fail --silent --show-error -o "$CRED_FILE" \
            "https://raw.githubusercontent.com/ROYJohan08/AubeZero/main/Cerbere/credentials.env"; then
            log "[-] Téléchargement GitHub impossible : arrêt"
            exit 1
        fi
        log "[+] Fichier GitHub récupéré"
        echo "[~] Merci de remplit les credentials avant de relancer le script"
        exit 1
    fi
    chown root:root "$CRED_FILE"
    chmod 600 "$CRED_FILE"
    log "[+] Permissions sécurisées appliquées"
fi

# --- Chargement du fichier ---
if [[ -f "$CRED_FILE" ]]; then
    source "$CRED_FILE"
    log "[+] Credentials chargés"
else
    log "[-] Credentials absent après tentative de récupération : arrêt"
    exit 1
fi

# --- Synchronisation GitHub ---
log "[~] Synchronisation des variables via GitHub"
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
    log "[-] Impossible de récupérer GitHub pour synchronisation : arrêt"
    exit 1
fi
# --- FIN ---
log "[✓] Fin du programme"
