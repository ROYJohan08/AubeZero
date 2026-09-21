#!/bin/sh
# Cerbere - Watchdog
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation et configuration du watchdog Cerbere

set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# === 2. Répertoires et configuration Cerbere ===
BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

mkdir -p "$CERBERE_DIR"

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-WATCHDOG.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début de l'installation et configuration du Watchdog"

# Redirection globale de stdout vers le log Mnémosyne
exec 1>>"$LOG_FILE"

# === 4. Variables de configuration ===
REPAIR_SCRIPT="$CERBERE_DIR/network-repair.sh"
MAX_LOAD="${MAX_LOAD:-24}"
MIN_MEM="${MIN_MEM:-1}"
PING_TARGET="${PING_TARGET:-1.1.1.1}"

# === 5. Configuration kernel auto-reboot ===
SYSCTL_CONF="/etc/sysctl.d/99-autoreboot.conf"

if [ ! -f "$SYSCTL_CONF" ]; then
    log "+" "Configuration des paramètres kernel d'auto-reboot..."
    cat << 'EOF' > "$SYSCTL_CONF"
kernel.panic = 10
kernel.hung_task_timeout_secs = 120
vm.panic_on_oom = 1
EOF
    sysctl --system > /dev/null 2>&1 || true
else
    log "=" "La configuration kernel auto-reboot existe déjà."
fi

# === 6. Installation du paquet watchdog ===
if ! command -v watchdog >/dev/null 2>&1; then
    log "~" "Installation du paquet watchdog..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq > /dev/null 2>&1
        apt-get install -y -qq watchdog > /dev/null 2>&1
        log "+" "Paquet watchdog installé avec succès."
    else
        log "[-]" "Gestionnaire de paquets non supporté."
        exit 1
    fi
else
    log "=" "Le paquet watchdog est déjà installé."
fi

# === 7. Création du script de réparation réseau ===
if [ ! -f "$REPAIR_SCRIPT" ]; then
    log "+" "Création du script de réparation : $REPAIR_SCRIPT"

    cat << EOF > "$REPAIR_SCRIPT"
#!/bin/sh
# Cerbere - NetworkRepair
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Script de secours réseau exécuté par Watchdog

set -eu

PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
mkdir -p "\$PATH_MNEMOSYNE"
DATE_LOG=\$(date +'%Y%m%d')
LOG_FILE="\$PATH_MNEMOSYNE/\${DATE_LOG}-CERBERE-NETWORKREPAIR.log"

log() {
    _tag="\$1"
    _msg="\$2"
    echo "[\$_tag] - \$(date +'%Y-%m-%d %H:%M:%S') - \$_msg" >> "\$LOG_FILE"
}

log "~" "Perte de connexion détectée. Redémarrage de systemd-networkd..."
systemctl restart systemd-networkd >/dev/null 2>&1 || true
sleep 5

if ping -c 1 -W 2 "$PING_TARGET" > /dev/null 2>&1; then
    log "+" "Connexion réseau rétablie avec succès."
    exit 0
else
    log "[-]" "Échec du rétablissement réseau. Déclenchement du redémarrage..."
    exit 1
fi
EOF

    chmod +x "$REPAIR_SCRIPT"
else
    log "=" "Le script de réparation réseau existe déjà."
fi

# === 8. Configuration watchdog.conf ===
WATCHDOG_CONF="/etc/watchdog.conf"

if [ ! -f "$WATCHDOG_CONF" ] || [ ! -f "${WATCHDOG_CONF}.bak" ]; then

    if [ -f "$WATCHDOG_CONF" ] && [ ! -f "${WATCHDOG_CONF}.bak" ]; then
        cp "$WATCHDOG_CONF" "${WATCHDOG_CONF}.bak" > /dev/null 2>&1
    fi

    log "+" "Configuration initiale de $WATCHDOG_CONF..."

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
    log "=" "Le fichier $WATCHDOG_CONF existe déjà. Configuration conservée."
fi

# === 9. Activation du service watchdog ===
systemctl enable watchdog --now > /dev/null 2>&1 || true

log "✓" "Installation et configuration du Watchdog terminées"
