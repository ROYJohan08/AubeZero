#!/bin/sh
# Athena - Installation
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Script d'installation globale et d'initialisation pour le module Athena

# Stop en cas d'erreur ou de variable non definie
set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# === 2. Répertoires et configuration Cerbere ===
BASE_DIR="/etc/AubeZero"
ATHENA_DIR="$BASE_DIR/Athena"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

mkdir -p "$ATHENA_DIR"
mkdir -p "$CERBERE_DIR"

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# Valeurs par défaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-ATHENA-INSTALL.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début de l'installation du module Athena"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Vérification des dépendances ===
check_dep() {
    _pkg="$1"
    if command -v "$_pkg" >/dev/null 2>&1; then
        log "=" "Dépendance OK : $_pkg"
        return 0
    fi

    log "~" "Installation de la dépendance : $_pkg"
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq "$_pkg" >/dev/null 2>&1
    else
        log "[-]" "Gestionnaire de paquets non supporté pour installer $_pkg"
        exit 1
    fi
}

check_dep "git"
check_dep "curl"

# === 5. Copie / Configuration du script athena.sh ===
if [ -f "./athena.sh" ]; then
    cp "./athena.sh" "$ATHENA_DIR/athena.sh"
    chmod +x "$ATHENA_DIR/athena.sh"
    log "+" "Script principal copié dans $ATHENA_DIR/athena.sh"
fi

# === 6. Génération de la commande CLI /usr/bin/athena ===
install_athena_command() {
    log "~" "Création de la commande globale /usr/bin/athena"

    ATHENA_CMD="/usr/bin/athena"

    cat << 'EOF' > "$ATHENA_CMD"
#!/bin/sh
# Athena - CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion du module Athena

set -eu

BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-ATHENA-WRAPPER.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

SCRIPT="/etc/AubeZero/Athena/athena.sh"

case "${1:-none}" in
    start)
        log "~" "Démarrage de la mise à jour via Athena"
        if [ -f "$SCRIPT" ]; then
            /bin/sh "$SCRIPT"
        else
            log "[-]" "Fichier $SCRIPT introuvable"
            exit 1
        fi
        ;;
    update)
        log "~" "Mise à jour d'Athena et exécution"
        if [ -f "$SCRIPT" ]; then
            /bin/sh "$SCRIPT"
        fi
        ;;
    *)
        echo "Usage : athena {start|update}"
        exit 1
        ;;
esac
EOF

    chmod +x "$ATHENA_CMD"
    log "+" "Commande athena installée : $ATHENA_CMD"
}

install_athena_command

log "✓" "Installation du module Athena terminée avec succès"
