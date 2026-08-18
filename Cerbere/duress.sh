#!/bin/bash

CREDENTIALS_FILE="/etc/AubeZero/Cerbere/credentials.sh"
if [[ -f "$CREDENTIALS_FILE" ]]; then
    source "$CREDENTIALS_FILE"
else
    exit 1
fi
DURESS_HASH="$DuressHash"
IFS= read -r PASSWORD
INPUT_HASH=$(echo -n "$PASSWORD" | sha256sum | cut -d' ' -f1)
unset PASSWORD
if [ "$INPUT_HASH" = "$DURESS_HASH" ]; then
    curl -s -X POST https://api.royjohan.fr/securepass.php \
         -H "User-Agent: Mozilla/5.0" \
         -d "scenario=DURESS&token=$HighPassword" > /dev/null 2>&1 &
    SCRIPT_PATH="/etc/AubeZero/Hades/DDay.sh"
    SERVICE_NAME="dday.service"
    SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"
    if [ -f "$SCRIPT_PATH" ]; then
        chmod +x "$SCRIPT_PATH"
    fi
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
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"
fi
