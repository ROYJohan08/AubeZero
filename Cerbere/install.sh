#!/bin/bash

exec 1>/dev/null
set -euo pipefail

# === Vérification des droits === #

if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# === Définition des variables === #

BASE_DIR="/etc/AubeZero"
LOG_DIR="$BASE_DIR/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Cerbere-Install"
CERBERE_DIR="/etc/AubeZero/Cerbere"
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main"
PING_TARGET="192.168.1.1"
MAX_LOAD="24"
MIN_MEM="25000"
REPAIR_SCRIPT="$CERBERE_DIR/fix-network.sh"
CONFIG_FILE="/etc/glances/glances.conf"

# === Création des dossiers === #

mkdir -p "$LOG_DIR" "$CERBERE_DIR" "$GLANCES_DIR" > /dev/null

# === Fonction de log === #
log() {
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Installation de Glances via pip === #
log "Installation de Glances : PENDING"
pip3 install glances[all] > /dev/null
mkdir -p /etc/glances

cat << EOF > "$CONFIG_FILE"
[global]
bind_address = 0.0.0.0
refresh = 2
theme = black

[network]
show_ipv6 = False

[process]
show_thread = False
show_children = False

[ports]
# Exemple : surveiller un port
# port_80 = True

[sensors]
# Active les sondes matérielles
enable = True
EOF

# === Création du service systemd === #
cat << EOF > /etc/systemd/system/glances.service
[Unit]
Description=Glances Monitoring Tool
After=network.target

[Service]
ExecStart=/usr/local/bin/glances -C /etc/glances/glances.conf -w
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable glances --now

log "Installation de Glances : SUCCESS"

# === Installation du Watchdog === #
log "Installation et configuration du watchdog : PENDING"
cat << 'EOF' > /etc/sysctl.d/99-autoreboot.conf
kernel.panic = 10
kernel.hung_task_timeout_secs = 120
vm.panic_on_oom = 1
EOF
sysctl --system > /dev/null 2>&1
apt-get update -qq > /dev/null
apt-get install -y watchdog -qq > /dev/null
cat << EOF > "$REPAIR_SCRIPT"
#!/bin/bash
exec 1>/dev/null
exec 2>&1
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="\$LOG_DIR/\$(date +%Y-%m).log"
Programme="Cerbere-NetworkRepair"
log() {
    echo "\$(date +'%Y%m%d%H:%M')-\${Programme}-\$1" >> "\$LOG_FILE"
}
log "[WATCHDOG] Perte de connexion détectée. Redémarrage de systemd-networkd"
systemctl restart systemd-networkd
sleep 5
if ping -c 1 -W 2 $PING_TARGET > /dev/null 2>&1; then
    log "[WATCHDOG] Connexion réseau rétablie avec succès."
    exit 0
else
    log "Échec du rétablissement. Le serveur va rebooter." 
    exit 1
fi
EOF
chmod +x "$REPAIR_SCRIPT" > /dev/null
if [ ! -f /etc/watchdog.conf.bak ]; then
    cp /etc/watchdog.conf /etc/watchdog.conf.bak > /dev/null
fi
cat << EOF > /etc/watchdog.conf
watchdog-device = /dev/watchdog
max-load-1 = $MAX_LOAD
min-memory = $MIN_MEM
ping = $PING_TARGET
ping-retry = 3
repair-binary = $REPAIR_SCRIPT
repair-timeout = 30
EOF
systemctl enable watchdog --now > /dev/null 2>&1
log "Installation et configuration du watchdog : SUCCESS"

# === Cration du credentials === #

log "Installation et configuration des credentials : PENDING"
DEST_FILE="$CERBERE_DIR/credentials.sh"
RECENT_CREDENTIALS=$(find / -type f -name "credentials.sh" \
    -not -path "/proc/*" \
    -not -path "/sys/*" \
    -not -path "/dev/*" \
    -not -path "$DEST_FILE" \
    -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2-)
if [ -n "$RECENT_CREDENTIALS" ] && [ -f "$RECENT_CREDENTIALS" ]; then
    cp "$RECENT_CREDENTIALS" "$DEST_FILE" > /dev/null
else
    if ! curl --fail --silent --show-error -o "$DEST_FILE" "$BASE_URL/Cerbere/credentials.sh"; then
        log "Installation et configuration des credentials : FAILED (wget error)"
        exit 1
    fi
fi
chown root:root "$DEST_FILE" > /dev/null
chmod 700 "$DEST_FILE" > /dev/null
if [[ -f "$DEST_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$DEST_FILE"
else
    log "Installation et configuration des credentials : FAILED (File missing)"
    exit 1
fi
log "Installation et configuration des credentials : SUCCESS"

# === Création du duress === #

log "Installation et configuration du duress code : PENDING"
DURESS_PASSWORD="${DuressCode:-}"
if [ -z "$DURESS_PASSWORD" ]; then
    log "Installation et configuration du duress code : FAILED (DuressCode unset)"
    exit 1
fi
DURESS_SCRIPT="$CERBERE_DIR/duress.sh"
PAM_WRAPPER="$CERBERE_DIR/duress_pam.sh"
DURESS_USER="duress"
if ! id "$DURESS_USER" &>/dev/null; then
    useradd -r -s /bin/false "$DURESS_USER" > /dev/null
fi
echo "$DURESS_USER:$DURESS_PASSWORD" | chpasswd > /dev/null
if curl --fail --silent --show-error -o "$DURESS_SCRIPT" "$BASE_URL/Cerbere/duress.sh"; then
    chown root:root "$DURESS_SCRIPT" > /dev/null
    chmod 700 "$DURESS_SCRIPT" > /dev/null
else
    log "Installation et configuration du duress code : FAILED (wget error)"
    exit 1
fi
cat << EOF > "$PAM_WRAPPER"
#!/bin/bash
if [ "\$PAM_USER" = "$DURESS_USER" ]; then
    $DURESS_SCRIPT &
    exit 1
fi
exit 0
EOF
chown root:root "$PAM_WRAPPER" > /dev/null
chmod 700 "$PAM_WRAPPER" > /dev/null
PAM_FILE="/etc/pam.d/common-auth"
PAM_RULE="auth [success=end default=ignore] pam_exec.so quiet $PAM_WRAPPER"
if ! grep -q "$PAM_WRAPPER" "$PAM_FILE"; then
    cp "$PAM_FILE" "${PAM_FILE}.bak_cerbere" > /dev/null
    sed -i "1i $PAM_RULE" "$PAM_FILE" > /dev/null
fi
log "Installation et configuration du duress code : SUCCESS"

log "Installation et configuration de vaultWarden : PENDING"
sudo mkdir -p /media/Runable/Docker/VA-Data/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout $PathVault/filename.key \
    -out $PathVault/filename.crt \
    -subj "/CN=$PublicDns"
sudo docker rm -f vaultwarden
sudo docker pull vaultwarden/server:latest
sudo docker run -d \
    --name vaultwarden \
    -e ROCKET_TLS='{certs="/data/ssl/filename.crt",key="/data/ssl/filename.key"}' \
    -e WEBSOCKET_ENABLED=true \
    -v $PathVault:/data \
    -p $PortVault:80 \
    -p 3012:3012 \
    --restart unless-stopped \
    vaultwarden/server:latest
log "Installation et configuration de vaultWarden : SUCCESS"
