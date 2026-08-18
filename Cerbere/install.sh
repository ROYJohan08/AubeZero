#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi
set -e
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Cerbere-Install"
CERBERE_DIR="/etc/AubeZero/Cerbere"
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main"
PING_TARGET="192.168.1.1"
MAX_LOAD="24"
MIN_MEM="25000"
REPAIR_SCRIPT="$CERBERE_DIR/fix-network.sh"
mkdir -p "$LOG_DIR" "$CERBERE_DIR" > /dev/null
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration du watchdog : PENDING" >> "$LOG_FILE"
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
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="\$LOG_DIR/\$(date +%Y-%m).log"
Programme="Cerbere-NetworkRepair"
echo "\$(date +'%Y%m%d%H:%M')-\${Programme}-[WATCHDOG] Perte de connexion détectée. Redémarrage de systemd-networkd" >> "\$LOG_FILE"
systemctl restart systemd-networkd
sleep 5
if ping -c 1 -W 2 $PING_TARGET > /dev/null 2>&1; then
    echo "\$(date +'%Y%m%d%H:%M')-\${Programme}-[WATCHDOG] Connexion réseau rétablie avec succès." >> "\$LOG_FILE"
    exit 0
else
    echo "\$(date +'%Y%m%d%H:%M')-\${Programme}-[WATCHDOG] Échec du rétablissement. Le serveur va rebooter." >> "\$LOG_FILE"
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
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration du watchdog : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration des credentials : PENDING" >> "$LOG_FILE"
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
    if ! wget -q -N "$BASE_URL/Cerbere/credentials.sh" -O "$DEST_FILE"; then
        echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration des credentials : FAILED (wget error)" >> "$LOG_FILE"
        echo "Erreur : Impossible de télécharger credentials.sh" >&2
        exit 1
    fi
fi
chown root:root "$DEST_FILE" > /dev/null
chmod 700 "$DEST_FILE" > /dev/null
if [[ -f "$DEST_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$DEST_FILE"
else
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration des credentials : FAILED (File missing)" >> "$LOG_FILE"
    exit 1
fi
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration des credentials : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration du duress code : PENDING" >> "$LOG_FILE"
DURESS_PASSWORD="${DuressCode:-}"
if [ -z "$DURESS_PASSWORD" ]; then
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration du duress code : FAILED (DuressCode unset)" >> "$LOG_FILE"
    echo "Erreur : La variable DuressCode est vide dans $DEST_FILE" >&2
    exit 1
fi
DURESS_SCRIPT="$CERBERE_DIR/duress.sh"
PAM_WRAPPER="$CERBERE_DIR/duress_pam.sh"
DURESS_USER="duress"
if ! id "$DURESS_USER" &>/dev/null; then
    useradd -r -s /bin/false "$DURESS_USER" > /dev/null
fi
echo "$DURESS_USER:$DURESS_PASSWORD" | chpasswd > /dev/null
if wget -q -N "$BASE_URL/Cerbere/duress.sh" -O "$DURESS_SCRIPT"; then
    chown root:root "$DURESS_SCRIPT" > /dev/null
    chmod 700 "$DURESS_SCRIPT" > /dev/null
else
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration du duress code : FAILED (wget error)" >> "$LOG_FILE"
    echo "Erreur : Impossible de télécharger $BASE_URL/Cerbere/duress.sh" >&2
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
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation et configuration du duress code : SUCCESS" >> "$LOG_FILE"
