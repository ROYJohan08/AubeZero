#!/bin/bash
# cerbere-watchdog.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:46
# @Desc : Installation et configuration du watchdog Cerbere

exec 1>/dev/null
set -euo pipefail

Programme="Cerbere-WatchDog"

# === Chargement des credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_CERBERE_PATH="/etc/AubeZero/Cerbere"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_CERBERE="$DEFAULT_CERBERE_PATH"
fi

# === LOG SYSTEM === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Installation du Watchdog === #
REPAIR_SCRIPT="${PATH_CERBERE:-$DEFAULT_CERBERE_PATH}/network-repair.sh"

# Fallback des variables
MAX_LOAD="${MAX_LOAD:-24}"
MIN_MEM="${MIN_MEM:-1}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"

log "[👉] Installation du watchdog"

# === Configuration kernel auto-reboot === #
SYSCTL_CONF="/etc/sysctl.d/99-autoreboot.conf"

if [[ ! -f "$SYSCTL_CONF" ]]; then
    log "[+] Configuration des paramètres kernel d'auto-reboot..."
    cat << 'EOF' > "$SYSCTL_CONF"
kernel.panic = 10
kernel.hung_task_timeout_secs = 120
vm.panic_on_oom = 1
EOF
    sysctl --system > /dev/null 2>&1
else
    log "[=] La configuration kernel auto-reboot existe déjà."
fi

# === Installation du paquet watchdog === #
if ! command -v watchdog &>/dev/null; then
    log "[~] Installation du paquet watchdog..."
    apt-get update -qq > /dev/null
    apt-get install -y watchdog -qq > /dev/null
    log "[+] Paquet watchdog installé."
else
    log "[=] Le paquet watchdog est déjà installé."
fi

# === Création du script de réparation réseau === #
mkdir -p "$(dirname "$REPAIR_SCRIPT")"

if [[ ! -f "$REPAIR_SCRIPT" ]]; then
    log "[+] Création du script de réparation : $REPAIR_SCRIPT"

    cat << EOF > "$REPAIR_SCRIPT"
#!/bin/bash
exec 1>/dev/null
exec 2>&1

Programme="Cerbere-NetworkRepair"

# === LOG SYSTEM === #
LOG_DIR="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
LOG_FILE="\${LOG_DIR}/\$(date +%Y-%m).log"

log() {
    mkdir -p "\$LOG_DIR" > /dev/null
    echo "\$(date +'%Y%m%d%H:%M')-\${Programme}-\$1" >> "\$LOG_FILE"
}

log "[WATCHDOG] Perte de connexion détectée. Redémarrage de systemd-networkd"
systemctl restart systemd-networkd
sleep 5

if ping -c 1 -W 2 $PING_TARGET > /dev/null 2>&1; then
    log "[WATCHDOG] Connexion réseau rétablie avec succès."
    exit 0
else
    log "[WATCHDOG] Échec du rétablissement. Le serveur va rebooter."
    exit 1
fi
EOF

    chmod +x "$REPAIR_SCRIPT" > /dev/null
else
    log "[=] Le script de réparation réseau existe déjà."
fi

# === Configuration watchdog.conf === #
WATCHDOG_CONF="/etc/watchdog.conf"

if [[ ! -f "$WATCHDOG_CONF" ]] || [[ ! -f "${WATCHDOG_CONF}.bak" ]]; then

    # Backup si nécessaire
    if [[ -f "$WATCHDOG_CONF" ]] && [[ ! -f "${WATCHDOG_CONF}.bak" ]]; then
        cp "$WATCHDOG_CONF" "${WATCHDOG_CONF}.bak" > /dev/null
    fi

    log "[+] Configuration initiale de $WATCHDOG_CONF..."

    cat << EOF > "$WATCHDOG_CONF"
watchdog-device = /dev/watchdog
max-load-1 = $MAX_LOAD
min-memory = $MIN_MEM
ping = $PING_TARGET
ping-retry = 3
repair-binary = $REPAIR_SCRIPT
repair-timeout = 30
EOF

else
    log "[=] Le fichier $WATCHDOG_CONF existe déjà. Configuration conservée."
fi

# === Activation du service watchdog === #
systemctl enable watchdog --now > /dev/null 2>&1

log "[✓] Installation et configuration du watchdog terminée"
