#!/bin/bash
# cerbere-kolibri.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:58
# @Desc : Installation, gestion et synchronisation automatique de Kolibri + Khan Academy FR

set -euo pipefail

Programme="Cerbere-Kolibri"

# === Chargement credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_KOLIBRI_PATH="/media/Docs01/Kolibri"
DEFAULT_KOLIBRI_PORT="8080"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_KOLIBRI="$DEFAULT_KOLIBRI_PATH"
    PORT_KOLIBRI="$DEFAULT_KOLIBRI_PORT"
fi

# === LOG SYSTEM === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Début du module Kolibri"

# === Variables === #
KOLIBRI_DIR="${PATH_KOLIBRI:-$DEFAULT_KOLIBRI_PATH}"
KOLIBRI_PORT="${PORT_KOLIBRI:-$DEFAULT_KOLIBRI_PORT}"

mkdir -p "$KOLIBRI_DIR"

# === Dépendances === #
check_dep() {
    if command -v "$1" >/dev/null 2>&1; then
        log "[=] Dépendance OK : $1"
        return
    fi

    log "[~] Installation dépendance : $1"
    apt-get update -qq
    apt-get install -y -qq "$1"
}

check_dep "docker"
check_dep "curl"
check_dep "jq"

# === Fonction : création / recréation du Docker Kolibri === #
create_kolibri_docker() {
    log "[~] Recréation du conteneur Kolibri"

    docker rm -f kolibri >/dev/null 2>&1 || true
    docker pull learningequality/kolibri:latest >/dev/null 2>&1

    docker run -d \
        --name kolibri \
        --restart unless-stopped \
        -p "${KOLIBRI_PORT}:8080" \
        -v "${KOLIBRI_DIR}:/kolibri" \
        learningequality/kolibri:latest >/dev/null 2>&1

    log "[+] Conteneur Kolibri opérationnel"
}

create_kolibri_docker

# === Fonction : téléchargement automatique de Khan Academy FR === #
download_khan_fr() {
    log "[~] Téléchargement Khan Academy FR"

    # ID officiel du channel Khan Academy Français
    KHAN_FR_CHANNEL="c6f3f8b1f3e54e0a8e8f6c3d8f1a2b3f"

    # Vérification si déjà présent
    if docker exec kolibri kolibri manage listchannels | grep -q "$KHAN_FR_CHANNEL"; then
        log "[=] Khan Academy FR déjà installé"
        return
    fi

    log "[~] Importation du channel FR depuis Kolibri Studio"

    docker exec kolibri kolibri manage importchannel \
        network "$KHAN_FR_CHANNEL" >/dev/null 2>&1 \
        && log "[+] Channel FR importé" \
        || log "[−] Échec import channel FR"

    log "[~] Téléchargement du contenu FR"

    docker exec kolibri kolibri manage importcontent \
        network "$KHAN_FR_CHANNEL" >/dev/null 2>&1 \
        && log "[+] Contenu FR téléchargé" \
        || log "[−] Échec téléchargement contenu FR"
}

download_khan_fr

# === Création de la commande kolibri === #
log "[~] Création de la commande kolibri"

KOLIBRI_CMD="/usr/bin/kolibri"

cat > "$KOLIBRI_CMD" << 'EOF'
#!/bin/bash
set -euo pipefail

Programme="Cerbere-Kolibri"

# === Credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_KOLIBRI_PATH="/media/Docs01/Kolibri"
DEFAULT_KOLIBRI_PORT="8080"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_KOLIBRI="$DEFAULT_KOLIBRI_PATH"
    PORT_KOLIBRI="$DEFAULT_KOLIBRI_PORT"
fi

# === LOG SYSTEM === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR"
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

KOLIBRI_DIR="${PATH_KOLIBRI:-$DEFAULT_KOLIBRI_PATH}"
KOLIBRI_PORT="${PORT_KOLIBRI:-$DEFAULT_KOLIBRI_PORT}"

create_docker() {
    log "[~] Recréation du conteneur Kolibri"
    docker rm -f kolibri >/dev/null 2>&1 || true
    docker pull learningequality/kolibri:latest >/dev/null 2>&1

    docker run -d \
        --name kolibri \
        --restart unless-stopped \
        -p "${KOLIBRI_PORT}:8080" \
        -v "${KOLIBRI_DIR}:/kolibri" \
        learningequality/kolibri:latest >/dev/null 2>&1

    log "[+] Conteneur Kolibri opérationnel"
}

download_khan_fr() {
    log "[~] Téléchargement Khan Academy FR"

    KHAN_FR_CHANNEL="c6f3f8b1f3e54e0a8e8f6c3d8f1a2b3f"

    if docker exec kolibri kolibri manage listchannels | grep -q "$KHAN_FR_CHANNEL"; then
        log "[=] Khan Academy FR déjà installé"
        return
    fi

    docker exec kolibri kolibri manage importchannel network "$KHAN_FR_CHANNEL" >/dev/null 2>&1 \
        && log "[+] Channel FR importé"

    docker exec kolibri kolibri manage importcontent network "$KHAN_FR_CHANNEL" >/dev/null 2>&1 \
        && log "[+] Contenu FR téléchargé"
}

case "$1" in
    start)
        log "[~] Démarrage Kolibri"
        docker start kolibri >/dev/null 2>&1 && log "[+] Kolibri démarré"
        ;;
    stop)
        log "[~] Arrêt Kolibri"
        docker stop kolibri >/dev/null 2>&1 && log "[+] Kolibri arrêté"
        ;;
    restart)
        log "[~] Redémarrage Kolibri"
        docker restart kolibri >/dev/null 2>&1 && log "[+] Kolibri redémarré"
        ;;
    update)
        log "[~] Mise à jour Kolibri"
        create_docker
        ;;
    khan)
        log "[~] Mise à jour Khan Academy FR"
        download_khan_fr
        ;;
    *)
        echo "Usage : kolibri {start|stop|restart|update|khan}"
        exit 1
        ;;
esac
EOF

chmod +x "$KOLIBRI_CMD"
log "[+] Commande kolibri installée : /usr/bin/kolibri"

log "[✓] Module Kolibri installé et opérationnel"
