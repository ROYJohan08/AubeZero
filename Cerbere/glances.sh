#!/bin/bash
set -euo pipefail
# === Vérification des droits === #
if [[ $EUID -ne 0 ]]; then
    log "[!] Erreur : ce script doit être exécuté en root."
    exit 1
fi

# === Variables AubeZero === #
CONFIG_FILE="/etc/glances/glances.conf"

log() {
    Programme="Cerbere-Glancews"
    mkdir -p "/etc/AubeZero/Mnemosyne/" > /dev/null
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "/etc/AubeZero/Mnemosyne/$(date +%Y-%m).log"
}

log "[START] Installation de Glances."

# === Vérification / installation des prérequis === #
if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
    log "[~] Python3/pip3 manquants. Installation…"
    if command -v apt-get &>/dev/null; then
        apt-get update -y >/dev/null
        apt-get install -y python3 python3-pip python3-full >/dev/null 2>&1
    elif command -v dnf &>/dev/null; then
        dnf install -y python3 python3-pip >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install -y python3 python3-pip >/dev/null 2>&1
    else
        log "[!] Impossible de déterminer le gestionnaire de paquets."
        exit 1
    fi
fi

if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
    log "[!] Échec de l'installation de Python3/pip3."
    exit 1
fi

log "[+] Prérequis validés."

# === Installation de Glances si absent === #
if command -v glances &>/dev/null; then
    log "[=] Glances déjà installé."
else
    log "[+] Installation de Glances via pip3…"
    pip3 install glances[all] --break-system-packages >/dev/null 2>&1 \
        || pip3 install glances[all] >/dev/null 2>&1
fi

# === Configuration === #
mkdir -p /etc/glances >/dev/null

if [[ -f "$CONFIG_FILE" ]]; then
    log "[=] Configuration déjà existante."
else
    log "[+] Génération du fichier de configuration…"
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
fi

# === Service systemd === #
SERVICE_FILE="/etc/systemd/system/glances.service"

if [[ -f "$SERVICE_FILE" ]]; then
    log "[=] Service systemd déjà présent."
else
    log "[+] Création du service systemd…"
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
fi

# === Vérification / lancement du service === #
if systemctl is-active --quiet glances; then
    log "[=] Glances est déjà actif."
else
    log "[+] Glances n'est pas actif. Démarrage…"
    systemctl start glances
fi

# === Validation finale === #
if systemctl is-active --quiet glances && command -v glances &>/dev/null; then
    log "[SUCCESS] Glances opérationnel."
else
    log "[!] Échec de la validation finale."
fi

log "[STOP] Installation et vérification de Glances."
