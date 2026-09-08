#!/bin/bash

exec 1>/dev/null
set -euo pipefail

# === Vérification des droits === #

if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

log() {
    Programme="Cerbere-Install"
    mkdir -p "/etc/AubeZero/Mnemosyne/" > /dev/null
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "/etc/AubeZero/Mnemosyne/$(date +%Y-%m).log"
}

# === Définition des variables === #

BASE_DIR="/etc/AubeZero"
CERBERE_DIR="/etc/AubeZero/Cerbere"
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main"
PING_TARGET="192.168.1.1"
MAX_LOAD="24"
MIN_MEM="25000"
REPAIR_SCRIPT="$CERBERE_DIR/fix-network.sh"
CONFIG_FILE="/etc/glances/glances.conf"

# === Création des dossiers === #
mkdir -P "$BASE_DIR" > /dev/null
mkdir -p "$CERBERE_DIR" > /dev/null


# === Installation de Glances via pip === #
log "[START] Installation de Glances."
if ! command -v python3 &> /dev/null || ! command -v pip3 &> /dev/null; then
    log "[+] Détection de paquets manquants (python3/pip3). Tentative d'installation..."  
    if command -v apt-get &> /dev/null; then
        sudo apt-get update -y > /dev/null
        sudo apt-get install -y python3 python3-pip python3-full > /dev/null 2>&1
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 python3-pip > /dev/null 2>&1
    elif command -v yum &> /dev/null; then
        sudo yum install -y python3 python3-pip > /dev/null 2>&1
    else
        log "[!] Erreur : Impossible de déterminer le gestionnaire de paquets (apt, dnf, yum)."
        log "[!] Veuillez installer 'python3' et 'python3-pip' manuellement."
        exit 1
    fi
fi
if ! command -v python3 &> /dev/null || ! command -v pip3 &> /dev/null; then
    log "[!] Erreur : Les prérequis Python 3 / pip3 n'ont pas pu être installés."
    exit 1
fi
log "[+] Prérequis validés."
if command -v glances &> /dev/null; then
    log "[=] Glances est déjà installé. Passage de l'étape d'installation."
else
    log "[+] Installation des dépendances et de Glances via pip3..."
    # Utilisation de --break-system-packages si nécessaire (Debian 12+ / Ubuntu 23.04+)
    pip3 install glances[all] --break-system-packages > /dev/null 2>&1 || pip3 install glances[all] > /dev/null 2>&1
fi
mkdir -p /etc/glances > /dev/null
if [ -f "$CONFIG_FILE" ]; then
    log "[=] Le fichier de configuration $CONFIG_FILE existe déjà. Aucune modification apportée."
else
    log "[+] Fichier de configuration absent. Génération de $CONFIG_FILE..."
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
fi

if [ -f "$CONFIG_FILE" ] && command -v glances &> /dev/null; then
    log "[+] Glances est opérationnel avec son fichier de configuration."
else
    log "[!] Erreur lors de la validation finale de l'installation."
fi
log "[STOP] Installation de Glances."

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

log "Installation et configuration de portainer : PENDING"
sudo docker rm -f portainer
sudo docker pull portainer/portainer-ce:latest
sudo docker run -d \
    --name portainer \
    --privileged \
    --restart=unless-stopped \
    -e TZ=CET \
    -p 8000:8000 \
    -p 9443:9443 \
    -p "$PortPortainer:9000" \
    -v $PathPortainerData:/var/run/docker.sock \
    -v "$PathPortainerConfig:/data" \
    portainer/portainer-ce:latest
log "Installation et configuration de portainer : SUCCESS"
