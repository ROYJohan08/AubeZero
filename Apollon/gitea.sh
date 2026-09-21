#!/bin/sh
# Cerbere - Gitea
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, mise à jour et miroir automatique du projet AubeZero dans Gitea

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

# Valeurs par défaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
DEFAULT_GITEA_PATH="/media/Docs01/Gitea"
DEFAULT_GITEA_PORT="3000"

GITEA_DIR="${PATH_GITEA:-$DEFAULT_GITEA_PATH}"
GITEA_PORT="${PORT_GITEA:-$DEFAULT_GITEA_PORT}"
AUBEZERO_GITHUB="https://github.com/ROYJohan08/AubeZero.git"
MIRROR_DIR="${GITEA_DIR}/mirror/AubeZero"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-GITEA.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Cerbere-Gitea"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Préparation de l'arborescence ===
mkdir -p "$GITEA_DIR"
mkdir -p "$(dirname "$MIRROR_DIR")"

# === 5. Vérification des dépendances ===
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
check_dep "git"

# === 6. Création / Recréation du conteneur Docker Gitea ===
create_gitea_docker() {
    log "~" "Recréation du conteneur Gitea..."

    docker rm -f gitea >/dev/null 2>&1 || true
    docker pull gitea/gitea:latest >/dev/null 2>&1

    if docker run -d \
        --name gitea \
        --restart unless-stopped \
        -p "${GITEA_PORT}:3000" \
        -p 2222:22 \
        -v "${GITEA_DIR}:/data" \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        gitea/gitea:latest >/dev/null 2>&1; then
        log "+" "Conteneur Gitea créé et opérationnel"
    else
        log "[-]" "Échec lors de la création du conteneur Gitea"
        exit 1
    fi
}

create_gitea_docker

# === 7. Miroir automatique du projet AubeZero ===
mirror_aubezero() {
    log "~" "Synchronisation du dépôt AubeZero vers le miroir local Gitea..."

    mkdir -p "$MIRROR_DIR"

    if [ ! -d "$MIRROR_DIR/.git" ]; then
        log "~" "Initialisation du miroir local Git..."
        if git clone --mirror "$AUBEZERO_GITHUB" "$MIRROR_DIR" >/dev/null 2>&1; then
            log "+" "Miroir initialisé avec succès"
        else
            log "[-]" "Échec de l'initialisation du miroir"
            exit 1
        fi
    else
        log "~" "Mise à jour du miroir local Git..."
        if git -C "$MIRROR_DIR" remote update >/dev/null 2>&1; then
            log "+" "Miroir mis à jour avec succès"
        else
            log "[-]" "Échec de la mise à jour du miroir"
        fi
    fi

    log "+" "Miroir AubeZero prêt pour import Gitea"
}

mirror_aubezero

# === 8. Génération de la commande CLI /usr/bin/gitea ===
install_gitea_command() {
    log "~" "Création de la commande globale /usr/bin/gitea"

    GITEA_CMD="/usr/bin/gitea"

    cat << 'EOF' > "$GITEA_CMD"
#!/bin/sh
# Cerbere - Gitea CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion pour le service Gitea et ses miroirs

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-GITEA.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

DEFAULT_GITEA_PATH="/media/Docs01/Gitea"
DEFAULT_GITEA_PORT="3000"

GITEA_DIR="${PATH_GITEA:-$DEFAULT_GITEA_PATH}"
GITEA_PORT="${PORT_GITEA:-$DEFAULT_GITEA_PORT}"
AUBEZERO_GITHUB="https://github.com/ROYJohan08/AubeZero.git"
MIRROR_DIR="${GITEA_DIR}/mirror/AubeZero"

create_docker() {
    log "~" "Recréation du conteneur Gitea..."
    docker rm -f gitea >/dev/null 2>&1 || true
    docker pull gitea/gitea:latest >/dev/null 2>&1

    if docker run -d \
        --name gitea \
        --restart unless-stopped \
        -p "${GITEA_PORT}:3000" \
        -p 2222:22 \
        -v "${GITEA_DIR}:/data" \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        gitea/gitea:latest >/dev/null 2>&1; then
        log "+" "Conteneur Gitea recréé et opérationnel"
    else
        log "[-]" "Erreur lors de la recréation du conteneur Gitea"
        exit 1
    fi
}

mirror_repo() {
    log "~" "Synchronisation du dépôt AubeZero vers le miroir..."

    mkdir -p "$MIRROR_DIR"

    if [ ! -d "$MIRROR_DIR/.git" ]; then
        log "~" "Initialisation du miroir local..."
        if git clone --mirror "$AUBEZERO_GITHUB" "$MIRROR_DIR" >/dev/null 2>&1; then
            log "+" "Miroir initialisé"
        else
            log "[-]" "Échec de l'initialisation du miroir"
            exit 1
        fi
    else
        log "~" "Mise à jour du miroir local..."
        if git -C "$MIRROR_DIR" remote update >/dev/null 2>&1; then
            log "+" "Miroir mis à jour"
        else
            log "[-]" "Échec de la mise à jour du miroir"
        fi
    fi
}

case "${1:-none}" in
    start)
        log "~" "Démarrage du service Gitea"
        docker start gitea >/dev/null 2>&1 && log "+" "Gitea démarré"
        ;;
    stop)
        log "~" "Arrêt du service Gitea"
        docker stop gitea >/dev/null 2>&1 && log "+" "Gitea arrêté"
        ;;
    restart)
        log "~" "Redémarrage du service Gitea"
        docker restart gitea >/dev/null 2>&1 && log "+" "Gitea redémarré"
        ;;
    update)
        log "~" "Mise à jour du service Gitea"
        create_docker
        ;;
    mirror)
        log "~" "Exécution de la synchronisation du miroir AubeZero"
        mirror_repo
        ;;
    *)
        echo "Usage : gitea {start|stop|restart|update|mirror}"
        exit 1
        ;;
esac
EOF

    chmod +x "$GITEA_CMD"
    log "+" "Commande gitea installée : $GITEA_CMD"
}

install_gitea_command

log "✓" "Module Cerbere-Gitea installé et opérationnel"
