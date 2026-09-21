#!/bin/sh
# Cerbere - Glancews
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, configuration et activation du service Glances pour AubeZero

# Stop en cas d'erreur ou de variable non definie
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

# Chargement dynamique du fichier credentials.env s'il existe
if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# Valeurs par défaut codées en dur
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-GLANCEWS.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début de l'installation de Glances"

# Redirection de stdout globale vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Variables de service ===
CONFIG_FILE="/etc/glances/glances.conf"
SERVICE_FILE="/etc/systemd/system/glances.service"

# === 5. Vérification / Installation Python3 + pip3 ===
if ! command -v python3 >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
    log "~" "Python3/pip3 manquants : installation"

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq 2>/dev/null || true
        apt-get install -y -qq python3 python3-pip python3-full >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q python3 python3-pip >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q python3 python3-pip >/dev/null 2>&1 || true
    else
        log "[-]" "Gestionnaire de paquets inconnu : arrêt"
        echo "[-] Erreur : Gestionnaire de paquets non supporté." >&2
        exit 1
    fi
fi

if ! command -v python3 >/dev/null 2>&1 || ! command -v pip3 >/dev/null 2>&1; then
    log "[-]" "Échec de l'installation de Python3/pip3"
    echo "[-] Erreur : Python3 ou Pip3 introuvable." >&2
    exit 1
fi
log "+" "Python3/pip3 disponibles"

# === 6. Installation de Glances ===
if command -v glances >/dev/null 2>&1; then
    log "=" "Glances déjà installé"
else
    log "~" "Installation de Glances via pip3"
    pip3 install glances[all] --break-system-packages >/dev/null 2>&1 \
        || pip3 install glances[all] >/dev/null 2>&1 || true

    if ! command -v glances >/dev/null 2>&1; then
        log "[-]" "Échec de l'installation de Glances"
        echo "[-] Erreur : Échec lors de l'installation de Glances." >&2
        exit 1
    fi
    log "+" "Glances installé avec succès"
fi

# === 7. Configuration de Glances ===
mkdir -p /etc/glances >/dev/null 2>&1 || true

if [ -f "$CONFIG_FILE" ]; then
    log "=" "Configuration Glances déjà existante"
else
    log "~" "Génération du fichier de configuration $CONFIG_FILE"
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

[sensors]
enable = True
EOF
    log "+" "Configuration de Glances générée"
fi

# === 8. Service systemd ===
if [ -f "$SERVICE_FILE" ]; then
    log "=" "Service systemd déjà présent"
else
    log "~" "Création du service systemd $SERVICE_FILE"
    
    GLANCES_BIN=$(command -v glances || echo "/usr/local/bin/glances")
    
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Glances Monitoring Tool
After=network.target

[Service]
ExecStart=$GLANCES_BIN -C /etc/glances/glances.conf -w
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable glances >/dev/null 2>&1 || true
    log "+" "Service systemd Glances configuré"
fi

# === 9. Démarrage et validation du service ===
if systemctl is-active --quiet glances 2>/dev/null; then
    log "=" "Glances est déjà actif"
else
    log "~" "Démarrage du service Glances"
    systemctl start glances >/dev/null 2>&1 || true
fi

if systemctl is-active --quiet glances 2>/dev/null && command -v glances >/dev/null 2>&1; then
    log "✓" "Glances est opérationnel"
else
    log "[-]" "Échec de la validation du service Glances"
    echo "[-] Erreur : Le service Glances n'a pas pu démarrer." >&2
    exit 1
fi

log "✓" "Installation et vérification de Cerbere-Glancews terminées avec succès"
