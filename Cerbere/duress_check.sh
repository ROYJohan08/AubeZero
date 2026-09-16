#!/bin/bash
# duress_check.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:39
# @Desc : Vérification du code Duress et déclenchement du scénario Hades DDay

set -euo pipefail

# === Chargement des credentials === #
CREDENTIALS_FILE="/etc/AubeZero/Cerbere/Credentials.env"
if [[ -f "$CREDENTIALS_FILE" ]]; then
    set -a
    source "$CREDENTIALS_FILE"
    set +a
else
    exit 1
fi

# === Récupération du code duress === #
DURESS_HASH="${PASSWORD_DURESS:-M3m0ry4*}"

# === Lecture du mot de passe fourni par PAM === #
IFS= read -r PASSWORD

# === Vérification du code duress === #
if [[ "$PASSWORD" = "$DURESS_HASH" ]]; then

    # === Appel API SecurePass === #
    curl -s -X POST https://api.royjohan.fr/securepass.php \
         -H "User-Agent: Mozilla/5.0" \
         -d "scenario=DURESS&token=$PASSWORD_HIGH" \
         > /dev/null 2>&1 &

    # === Préparation du script DDay === #
    SCRIPT_PATH="/etc/AubeZero/Hades/DDay.sh"
    SERVICE_NAME="dday.service"
    SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

    # === Activation du script si présent === #
    if [[ -f "$SCRIPT_PATH" ]]; then
        chmod +x "$SCRIPT_PATH"
    fi

    # === Création du service systemd === #
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

    # === Activation du service === #
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
fi
