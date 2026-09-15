#!/bin/bash
# cerbere-gitea.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:55
# @Desc : Installation, mise à jour et miroir automatique du projet AubeZero dans Gitea

set -euo pipefail

Programme="Cerbere-Gitea"

# === Chargement credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_GITEA_PATH="/media/Docs01/Gitea"
DEFAULT_GITEA_PORT="3000"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_GITEA="$DEFAULT_GITEA_PATH"
    PORT_GITEA="$DEFAULT_GITEA_PORT"
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

log "[👉] Début du module Gitea"

# === Variables === #
GITEA_DIR="${PATH_GITEA:-$DEFAULT_GITEA_PATH}"
GITEA_PORT="${PORT_GITEA:-$DEFAULT_GITEA_PORT}"
AUBEZERO_GITHUB="https://github.com/ROYJohan08/AubeZero.git"
MIRROR_DIR="${GITEA_DIR}/mirror/AubeZero"

mkdir -p "$GITEA_DIR"
mkdir -p "$(dirname "$MIRROR_DIR")"

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
check_dep "git"

# === Fonction : création / recréation du Docker Gitea === #
create_gitea_docker() {
    log "[~] Recréation du conteneur Gitea"

    docker rm -f gitea >/dev/null 2>&1 || true
    docker pull gitea/gitea:latest >/dev/null 2>&1

    docker run -d \
        --name gitea \
        --restart unless-stopped \
        -p "${GITEA_PORT}:3000" \
        -p 2222:22 \
        -v "${GITEA_DIR}:/data" \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        gitea/gitea:latest >/dev/null 2>&1

    log "[+] Conteneur Gitea opérationnel"
}

create_gitea_docker

# === Fonction : miroir automatique du projet AubeZero === #
mirror_aubezero() {
    log "[~] Synchronisation du projet AubeZero → Gitea"

    mkdir -p "$MIRROR_DIR"

    if [[ ! -d "$MIRROR_DIR/.git" ]]; then
        log "[~] Initialisation du miroir local"
        git clone --mirror "$AUBEZERO_GITHUB" "$MIRROR_DIR" >/dev/null 2>&1 \
            && log "[+] Miroir initialisé" \
            || { log "[−] Échec initialisation miroir"; exit 1; }
    else
        log "[~] Mise à jour du miroir local"
        git -C "$MIRROR_DIR" remote update >/dev/null 2>&1 \
            && log "[+] Miroir mis à jour" \
            || log "[−] Échec mise à jour miroir"
    fi

    log "[+] Miroir AubeZero prêt pour import Gitea"
}

mirror_aubezero

# === Création de la commande gitea === #
log "[~] Création de la commande gitea"

GITEA_CMD="/usr/bin/gitea"

cat > "$GITEA_CMD" << 'EOF'
#!/bin/bash
set -euo pipefail

Programme="Cerbere-Gitea"

# === Credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_GITEA_PATH="/media/Docs01/Gitea"
DEFAULT_GITEA_PORT="3000"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_GITEA="$DEFAULT_GITEA_PATH"
    PORT_GITEA="$DEFAULT_GITEA_PORT"
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

GITEA_DIR="${PATH_GITEA:-$DEFAULT_GITEA_PATH}"
GITEA_PORT="${PORT_GITEA:-$DEFAULT_GITEA_PORT}"
AUBEZERO_GITHUB="https://github.com/ROYJohan08/AubeZero.git"
MIRROR_DIR="${GITEA_DIR}/mirror/AubeZero"

create_docker() {
    log "[~] Recréation du conteneur Gitea"
    docker rm -f gitea >/dev/null 2>&1 || true
    docker pull gitea/gitea:latest >/dev/null 2>&1

    docker run -d \
        --name gitea \
        --restart unless-stopped \
        -p "${GITEA_PORT}:3000" \
        -p 2222:22 \
        -v "${GITEA_DIR}:/data" \
        -v /etc/timezone:/etc/timezone:ro \
        -v /etc/localtime:/etc/localtime:ro \
        gitea/gitea:latest >/dev/null 2>&1

    log "[+] Conteneur Gitea opérationnel"
}

mirror_repo() {
    log "[~] Synchronisation du projet AubeZero → Gitea"

    mkdir -p "$MIRROR_DIR"

    if [[ ! -d "$MIRROR_DIR/.git" ]]; then
        log "[~] Initialisation du miroir local"
        git clone --mirror "$AUBEZERO_GITHUB" "$MIRROR_DIR" >/dev/null 2>&1 \
            && log "[+] Miroir initialisé" \
            || { log "[−] Échec initialisation miroir"; exit 1; }
    else
        log "[~] Mise à jour du miroir local"
        git -C "$MIRROR_DIR" remote update >/dev/null 2>&1 \
            && log "[+] Miroir mis à jour" \
            || log "[−] Échec mise à jour miroir"
    fi
}

case "$1" in
    start)
        log "[~] Démarrage Gitea"
        docker start gitea >/dev/null 2>&1 && log "[+] Gitea démarré"
        ;;
    stop)
        log "[~] Arrêt Gitea"
        docker stop gitea >/dev/null 2>&1 && log "[+] Gitea arrêté"
        ;;
    restart)
        log "[~] Redémarrage Gitea"
        docker restart gitea >/dev/null 2>&1 && log "[+] Gitea redémarré"
        ;;
    update)
        log "[~] Mise à jour Gitea"
        create_docker
        ;;
    mirror)
        log "[~] Miroir AubeZero → Gitea"
        mirror_repo
        ;;
    *)
        echo "Usage : gitea {start|stop|restart|update|mirror}"
        exit 1
        ;;
esac
EOF

chmod +x "$GITEA_CMD"
log "[+] Commande gitea installée : /usr/bin/gitea"

log "[✓] Module Gitea installé et opérationnel"
