#!/bin/bash
set -euo pipefail

# === LOG SYSTEM === #
Programme="Cerbere-Glancews"
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Début de l'installation de Glances"

# === Vérification des droits === #
if [[ $EUID -ne 0 ]]; then
    log "[-] Ce script doit être exécuté en root"
    exit 1
fi
log "[+] Droits root confirmés"

# === Variables === #
CONFIG_FILE="/etc/glances/glances.conf"
SERVICE_FILE="/etc/systemd/system/glances.service"

# === Vérification / installation Python3 + pip3 === #
if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
    log "[~] Python3/pip3 manquants : installation"

    if command -v apt-get &>/dev/null; then
        apt-get update -y >/dev/null
        apt-get install -y python3 python3-pip python3-full >/dev/null 2>&1
    elif command -v dnf &>/dev/null; then
        dnf install -y python3 python3-pip >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y python3 python3-pip >/dev/null 2>&1
    else
        log "[-] Gestionnaire de paquets inconnu : arrêt"
        exit 1
    fi
fi

if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
    log "[-] Échec de l'installation de Python3/pip3"
    exit 1
fi

log "[+] Python3/pip3 disponibles"

# === Installation de Glances === #
if command -v glances &>/dev/null; then
    log "[=] Glances déjà installé"
else
    log "[~] Installation de Glances via pip3"
    pip3 install glances[all] --break-system-packages >/dev/null 2>&1 \
        || pip3 install glances[all] >/dev/null 2>&1

    if ! command -v glances &>/dev/null; then
        log "[-] Échec de l'installation de Glances"
        exit 1
    fi

    log "[+] Glances installé"
fi

# === Configuration === #
mkdir -p /etc/glances >/dev/null

if [[ -f "$CONFIG_FILE" ]]; then
    log "[=] Configuration Glances déjà existante"
else
    log "[~] Génération du fichier de configuration"

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
enable = True
EOF

    log "[+] Configuration générée"
fi

# === Service systemd === #
if [[ -f "$SERVICE_FILE" ]]; then
    log "[=] Service systemd déjà présent"
else
    log "[~] Création du service systemd"

    cat << EOF > "$SERVICE_FILE"
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
    systemctl enable glances >/dev/null

    log "[+] Service systemd installé"
fi

# === Vérification / lancement du service === #
if systemctl is-active --quiet glances; then
    log "[=] Glances déjà actif"
else
    log "[~] Démarrage du service Glances"
    systemctl start glances
fi

# === Validation finale === #
if systemctl is-active --quiet glances && command -v glances &>/dev/null; then
    log "[✓] Glances opérationnel"
else
    log "[-] Échec de la validation finale"
    exit 1
fi

log "[✓] Installation et vérification de Glances terminée"
