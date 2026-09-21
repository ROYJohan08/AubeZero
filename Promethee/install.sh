#!/bin/sh
# Promethee - Installation
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Script d'installation globale et d'initialisation pour le module Promethee

# Stop en cas d'erreur ou de variable non definie
set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# === 2. Répertoires et configuration Cerbere ===
BASE_DIR="/etc/AubeZero"
PROMETHEE_DIR="$BASE_DIR/Promethee"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

mkdir -p "$PROMETHEE_DIR"
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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-PROMETHEE-INSTALL.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début de l'installation du module Promethee"

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

check_dep "docker"
check_dep "curl"

# === 5. Installation des sous-modules Prométhée ===
# Déploiement du composant Jellyfin s'il est présent dans le répertoire source
if [ -f "./promethee-jellyfin.sh" ]; then
    log "~" "Déploiement du composant promethee-jellyfin.sh..."
    cp "./promethee-jellyfin.sh" "$PROMETHEE_DIR/promethee-jellyfin.sh"
    chmod +x "$PROMETHEE_DIR/promethee-jellyfin.sh"
    /bin/sh "$PROMETHEE_DIR/promethee-jellyfin.sh"
fi

# === 6. Génération de la commande CLI /usr/bin/promethee ===
install_promethee_command() {
    log "~" "Création de la commande globale /usr/bin/promethee"

    PROMETHEE_CMD="/usr/bin/promethee"

    cat << 'EOF' > "$PROMETHEE_CMD"
#!/bin/sh
# Promethee - CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion globale pour les services du module Promethee

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-PROMETHEE-WRAPPER.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

case "${1:-none}" in
    start)
        log "~" "Démarrage des services Promethee"
        if command -v jellyfin >/dev/null 2>&1; then
            jellyfin start
        fi
        ;;
    stop)
        log "~" "Arrêt des services Promethee"
        if command -v jellyfin >/dev/null 2>&1; then
            jellyfin stop
        fi
        ;;
    restart)
        log "~" "Redémarrage des services Promethee"
        if command -v jellyfin >/dev/null 2>&1; then
            jellyfin restart
        fi
        ;;
    update)
        log "~" "Mise à jour des services Promethee"
        if command -v jellyfin >/dev/null 2>&1; then
            jellyfin update
        fi
        ;;
    *)
        echo "Usage : promethee {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

    chmod +x "$PROMETHEE_CMD"
    log "+" "Commande promethee installée : $PROMETHEE_CMD"
}

install_promethee_command

log "✓" "Installation du module Promethee terminée avec succès"
