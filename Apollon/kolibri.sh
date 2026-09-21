#!/bin/sh
# Cerbere - Kolibri
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation, gestion et synchronisation automatique de Kolibri + Khan Academy FR

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
DEFAULT_KOLIBRI_PATH="/media/Docs01/Kolibri"
DEFAULT_KOLIBRI_PORT="8080"

KOLIBRI_DIR="${PATH_KOLIBRI:-$DEFAULT_KOLIBRI_PATH}"
KOLIBRI_PORT="${PORT_KOLIBRI:-$DEFAULT_KOLIBRI_PORT}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-KOLIBRI.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du module Cerbere-Kolibri"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Préparation du répertoire de travail ===
mkdir -p "$KOLIBRI_DIR"

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
check_dep "curl"
check_dep "jq"

# === 6. Création / Recréation du conteneur Docker Kolibri ===
create_kolibri_docker() {
    log "~" "Recréation du conteneur Kolibri..."

    docker rm -f kolibri >/dev/null 2>&1 || true
    docker pull learningequality/kolibri:latest >/dev/null 2>&1

    if docker run -d \
        --name kolibri \
        --restart unless-stopped \
        -p "${KOLIBRI_PORT}:8080" \
        -v "${KOLIBRI_DIR}:/kolibri" \
        learningequality/kolibri:latest >/dev/null 2>&1; then
        log "+" "Conteneur Kolibri créé et opérationnel"
    else
        log "[-]" "Échec lors de la création du conteneur Kolibri"
        exit 1
    fi
}

create_kolibri_docker

# === 7. Téléchargement automatique de Khan Academy FR ===
download_khan_fr() {
    log "~" "Vérification et téléchargement de Khan Academy FR..."

    KHAN_FR_CHANNEL="c6f3f8b1f3e54e0a8e8f6c3d8f1a2b3f"

    if docker exec kolibri kolibri manage listchannels 2>/dev/null | grep -q "$KHAN_FR_CHANNEL"; then
        log "=" "Khan Academy FR est déjà installé"
        return 0
    fi

    log "~" "Importation du canal FR depuis Kolibri Studio..."

    if docker exec kolibri kolibri manage importchannel network "$KHAN_FR_CHANNEL" >/dev/null 2>&1; then
        log "+" "Canal FR importé avec succès"
    else
        log "[-]" "Échec de l'importation du canal FR"
        return 1
    fi

    log "~" "Téléchargement du contenu FR..."

    if docker exec kolibri kolibri manage importcontent network "$KHAN_FR_CHANNEL" >/dev/null 2>&1; then
        log "+" "Contenu FR téléchargé avec succès"
    else
        log "[-]" "Échec du téléchargement du contenu FR"
        return 1
    fi
}

download_khan_fr || true

# === 8. Génération de la commande CLI /usr/bin/kolibri ===
install_kolibri_command() {
    log "~" "Création de la commande globale /usr/bin/kolibri"

    KOLIBRI_CMD="/usr/bin/kolibri"

    cat << 'EOF' > "$KOLIBRI_CMD"
#!/bin/sh
# Cerbere - Kolibri CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Commandes de gestion du service et contenu Kolibri

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-KOLIBRI.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

DEFAULT_KOLIBRI_PATH="/media/Docs01/Kolibri"
DEFAULT_KOLIBRI_PORT="8080"

KOLIBRI_DIR="${PATH_KOLIBRI:-$DEFAULT_KOLIBRI_PATH}"
KOLIBRI_PORT="${PORT_KOLIBRI:-$DEFAULT_KOLIBRI_PORT}"

create_docker() {
    log "~" "Recréation du conteneur Kolibri..."
    docker rm -f kolibri >/dev/null 2>&1 || true
    docker pull learningequality/kolibri:latest >/dev/null 2>&1

    if docker run -d \
        --name kolibri \
        --restart unless-stopped \
        -p "${KOLIBRI_PORT}:8080" \
        -v "${KOLIBRI_DIR}:/kolibri" \
        learningequality/kolibri:latest >/dev/null 2>&1; then
        log "+" "Conteneur Kolibri recréé et opérationnel"
    else
        log "[-]" "Échec de la recréation du conteneur Kolibri"
        exit 1
    fi
}

download_khan_fr() {
    log "~" "Téléchargement / Mise à jour Khan Academy FR..."

    KHAN_FR_CHANNEL="c6f3f8b1f3e54e0a8e8f6c3d8f1a2b3f"

    if docker exec kolibri kolibri manage listchannels 2>/dev/null | grep -q "$KHAN_FR_CHANNEL"; then
        log "=" "Khan Academy FR est déjà présent"
        return 0
    fi

    if docker exec kolibri kolibri manage importchannel network "$KHAN_FR_CHANNEL" >/dev/null 2>&1; then
        log "+" "Canal FR importé avec succès"
    fi

    if docker exec kolibri kolibri manage importcontent network "$KHAN_FR_CHANNEL" >/dev/null 2>&1; then
        log "+" "Contenu FR téléchargé avec succès"
    fi
}

case "${1:-none}" in
    start)
        log "~" "Démarrage du service Kolibri"
        docker start kolibri >/dev/null 2>&1 && log "+" "Kolibri démarré"
        ;;
    stop)
        log "~" "Arrêt du service Kolibri"
        docker stop kolibri >/dev/null 2>&1 && log "+" "Kolibri arrêté"
        ;;
    restart)
        log "~" "Redémarrage du service Kolibri"
        docker restart kolibri >/dev/null 2>&1 && log "+" "Kolibri redémarré"
        ;;
    update)
        log "~" "Mise à jour du service Kolibri"
        create_docker
        ;;
    khan)
        log "~" "Synchronisation Khan Academy FR"
        download_khan_fr
        ;;
    *)
        echo "Usage : kolibri {start|stop|restart|update|khan}"
        exit 1
        ;;
esac
EOF

    chmod +x "$KOLIBRI_CMD"
    log "+" "Commande kolibri installée : $KOLIBRI_CMD"
}

install_kolibri_command

log "✓" "Module Cerbere-Kolibri installé et opérationnel"
