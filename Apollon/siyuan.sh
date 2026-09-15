#!/bin/bash
# cerbere-siyuan.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:56
# @Desc : Installation, gestion et sécurisation du serveur SiYuan pour AubeZero

set -euo pipefail

Programme="Cerbere-SiYuan"

# === Chargement credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_SIYUAN_PATH="/media/Docs01/SiYuan"
DEFAULT_SIYUAN_PORT="6806"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_SIYUAN="$DEFAULT_SIYUAN_PATH"
    PORT_SIYUAN="$DEFAULT_SIYUAN_PORT"
    HIGH_PASSWORD="changeme"
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

log "[👉] Début du module SiYuan"

# === Variables === #
SIYUAN_DIR="${PATH_SIYUAN:-$DEFAULT_SIYUAN_PATH}"
SIYUAN_PORT="${PORT_SIYUAN:-$DEFAULT_SIYUAN_PORT}"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

mkdir -p "$SIYUAN_DIR"

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

# === Fonction : création / recréation du Docker SiYuan === #
create_siyuan_docker() {
    log "[~] Recréation du conteneur SiYuan (mot de passe masqué)"

    docker rm -f siyuan >/dev/null 2>&1 || true
    docker pull b3log/siyuan:latest >/dev/null 2>&1

    docker run -d \
        --name siyuan \
        --restart unless-stopped \
        -v "${SIYUAN_DIR}:/siyuan/workspace" \
        -p "${SIYUAN_PORT}:6806" \
        -e PUID="${USER_ID}" \
        -e PGID="${GROUP_ID}" \
        b3log/siyuan:latest \
        serve \
        --workspace=/siyuan/workspace \
        --accessAuthCode="${HIGH_PASSWORD}" >/dev/null 2>&1

    log "[+] Conteneur SiYuan opérationnel"
}

create_siyuan_docker

# === Création de la commande siyuan === #
log "[~] Création de la commande siyuan"

SIYUAN_CMD="/usr/bin/siyuan"

cat > "$SIYUAN_CMD" << 'EOF'
#!/bin/bash
set -euo pipefail

Programme="Cerbere-SiYuan"

# === Credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
DEFAULT_SIYUAN_PATH="/media/Docs01/SiYuan"
DEFAULT_SIYUAN_PORT="6806"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
    PATH_SIYUAN="$DEFAULT_SIYUAN_PATH"
    PORT_SIYUAN="$DEFAULT_SIYUAN_PORT"
    HIGH_PASSWORD="changeme"
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

SIYUAN_DIR="${PATH_SIYUAN:-$DEFAULT_SIYUAN_PATH}"
SIYUAN_PORT="${PORT_SIYUAN:-$DEFAULT_SIYUAN_PORT}"
USER_ID="$(id -u)"
GROUP_ID="$(id -g)"

create_docker() {
    log "[~] Recréation du conteneur SiYuan (mot de passe masqué)"
    docker rm -f siyuan >/dev/null 2>&1 || true
    docker pull b3log/siyuan:latest >/dev/null 2>&1

    docker run -d \
        --name siyuan \
        --restart unless-stopped \
        -v "${SIYUAN_DIR}:/siyuan/workspace" \
        -p "${SIYUAN_PORT}:6806" \
        -e PUID="${USER_ID}" \
        -e PGID="${GROUP_ID}" \
        b3log/siyuan:latest \
        serve \
        --workspace=/siyuan/workspace \
        --accessAuthCode="${HIGH_PASSWORD}" >/dev/null 2>&1

    log "[+] Conteneur SiYuan opérationnel"
}

case "$1" in
    start)
        log "[~] Démarrage SiYuan"
        docker start siyuan >/dev/null 2>&1 && log "[+] SiYuan démarré"
        ;;
    stop)
        log "[~] Arrêt SiYuan"
        docker stop siyuan >/dev/null 2>&1 && log "[+] SiYuan arrêté"
        ;;
    restart)
        log "[~] Redémarrage SiYuan"
        docker restart siyuan >/dev/null 2>&1 && log "[+] SiYuan redémarré"
        ;;
    update)
        log "[~] Mise à jour SiYuan"
        create_docker
        ;;
    *)
        echo "Usage : siyuan {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

chmod +x "$SIYUAN_CMD"
log "[+] Commande siyuan installée : /usr/bin/siyuan"

log "[✓] Module SiYuan installé et opérationnel"
