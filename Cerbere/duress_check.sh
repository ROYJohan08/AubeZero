#!/bin/sh
# Cerbere - Duress-Check
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Verification du code Duress et declenchement du scenario Hades DDay

# Stop en cas d'erreur ou de variable non definie
set -eu

# === 1. Chargement de la configuration ===
BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
else
    exit 1
fi

# Valeurs par defaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
DURESS_HASH="${PASSWORD_DURESS:-M3m0ry4*}"
TOKEN_HIGH="${PASSWORD_HIGH:-}"

# === 2. Initialisation de la journalisation Mnemosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-DURESS-CHECK.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

# Redirection globale de stdout vers le log Mnemosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 3. Lecture du mot de passe fourni par PAM ===
IFS= read -r PASSWORD || PASSWORD=""

# === 4. Verification du code Duress ===
if [ "$PASSWORD" = "$DURESS_HASH" ]; then
    log "⚠️" "Code Duress detecte ! Declenchement des procedures d'urgence"

    # === Appel API SecurePass en arriere-plan ===
    log "~" "Envoi du signal d'alerte SecurePass"
    curl -s -X POST https://api.royjohan.fr/securepass.php \
         -H "User-Agent: Mozilla/5.0" \
         -d "scenario=DURESS&token=$TOKEN_HIGH" \
         >/dev/null 2>&1 &

    # === Preparation et lancement du scenario Hades DDay ===
    SCRIPT_PATH="$BASE_DIR/Hades/DDay.sh"
    SERVICE_NAME="dday.service"
    SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

    if [ -f "$SCRIPT_PATH" ]; then
        chmod 700 "$SCRIPT_PATH" 2>/dev/null || true
        log "+" "Script $SCRIPT_PATH configure"
    else
        log "[-]" "Script $SCRIPT_PATH introuvable"
    fi

    log "~" "Creation du service systemd $SERVICE_NAME"
    cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Service Hades DDay
After=network.target

[Service]
Type=simple
User=root
ExecStart=$SCRIPT_PATH
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    log "~" "Activation et execution du service $SERVICE_NAME"
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl restart "$SERVICE_NAME" >/dev/null 2>&1 || true
    log "✓" "Scenario Hades DDay active avec succes"
fi
