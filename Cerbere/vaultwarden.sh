#!/bin/sh
# Cerbere - VaultWarden
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation et gestion du conteneur VaultWarden pour Cerbere

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

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-VAULTWARDEN.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du programme Cerbere-VaultWarden"

# Redirection de stdout globale vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Variables de configuration ===
DEFAULT_PORT=1013
DEFAULT_PATH="/media/Runable/Docker/VaultWarden"

vaultwarden_port="${PORT_VAULTWARDEN:-$DEFAULT_PORT}"
vaultwarden_data="${PATH_VAULTWARDEN:-$DEFAULT_PATH}"

log "~" "Port utilisé : $vaultwarden_port"
log "~" "Chemin utilisé : $vaultwarden_data"

# === 5. Installation de Docker (POSIX) ===
install_docker() {
    log "~" "Installation de Docker..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq >/dev/null 2>&1 || { log "[-]" "Impossible de mettre à jour apt"; exit 1; }
        apt-get install -y -qq ca-certificates curl gnupg lsb-release >/dev/null 2>&1 \
            || { log "[-]" "Impossible d'installer les dépendances Docker"; exit 1; }

        install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1
        curl -fsSL https://download.docker.com/linux/debian/gpg \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1 \
            || { log "[-]" "Impossible de récupérer la clé Docker"; exit 1; }

        chmod a+r /etc/apt/keyrings/docker.gpg >/dev/null 2>&1

        _arch=$(dpkg --print-architecture)
        _codename=$(lsb_release -cs 2>/dev/null || echo "stable")
        echo "deb [arch=$_arch signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $_codename stable" \
            > /etc/apt/sources.list.d/docker.list

        apt-get update -qq >/dev/null 2>&1 || { log "[-]" "Impossible de mettre à jour apt après ajout du dépôt"; exit 1; }
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 \
            || { log "[-]" "Impossible d'installer Docker"; exit 1; }

        log "+" "Docker installé avec succès"
    else
        log "[-]" "Gestionnaire de paquets non supporté pour l'installation automatique de Docker"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "~" "Docker absent : lancement de l'installation"
        install_docker
    else
        log "=" "Docker est déjà installé"
    fi
}

# === 6. Génération de la commande /usr/local/bin/vaultwarden ===
install_vaultwarden_command() {
    log "~" "Génération de la commande /usr/local/bin/vaultwarden"

    COMMAND_PATH="/usr/local/bin/vaultwarden"

    cat << 'EOF' > "$COMMAND_PATH"
#!/bin/sh
# Cerbere - VaultWarden CLI Wrapper
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Gestionnaire CLI du conteneur VaultWarden

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
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-VAULTWARDEN.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

VAULTWARDEN_PORT="${PORT_VAULTWARDEN:-1013}"
VAULTWARDEN_DATA="${PATH_VAULTWARDEN:-/media/Runable/Docker/VaultWarden}"

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[-]" "Docker n'est pas installé ou introuvable"
        echo "[-] Erreur : Docker n'est pas disponible." >&2
        exit 1
    fi
}

start_vaultwarden() {
    check_docker
    if docker start vaultwarden >/dev/null 2>&1; then
        log "+" "Vaultwarden démarré"
    else
        log "[-]" "Impossible de démarrer le conteneur Vaultwarden"
    fi
}

stop_vaultwarden() {
    check_docker
    if docker stop vaultwarden >/dev/null 2>&1; then
        log "+" "Vaultwarden arrêté"
    else
        log "[-]" "Impossible d'arrêter le conteneur Vaultwarden"
    fi
}

restart_vaultwarden() {
    check_docker
    if docker restart vaultwarden >/dev/null 2>&1; then
        log "+" "Vaultwarden redémarré"
    else
        log "[-]" "Impossible de redémarrer le conteneur Vaultwarden"
    fi
}

update_vaultwarden() {
    check_docker
    log "~" "Mise à jour de l'image Vaultwarden..."

    if ! docker pull vaultwarden/server:latest >/dev/null 2>&1; then
        log "[-]" "Téléchargement de la nouvelle image Vaultwarden échoué"
        exit 1
    fi

    docker rm -f vaultwarden >/dev/null 2>&1 || true
    log "~" "Ancien conteneur Vaultwarden supprimé"

    mkdir -p "$VAULTWARDEN_DATA" >/dev/null 2>&1 || true

    if docker run -d \
        --name vaultwarden \
        --restart unless-stopped \
        -v "$VAULTWARDEN_DATA:/data" \
        -p "${VAULTWARDEN_PORT}:80" \
        vaultwarden/server:latest >/dev/null 2>&1; then
        log "+" "Vaultwarden mis à jour et recréé avec succès"
    else
        log "[-]" "Échec lors de la recréation du conteneur Vaultwarden"
        exit 1
    fi
}

status_vaultwarden() {
    check_docker
    if docker ps --format '{{.Names}}' | grep -q "^vaultwarden$"; then
        log "=" "Vaultwarden est en cours d'exécution"
        echo "Vaultwarden est en cours d'exécution."
    else
        log "~" "Vaultwarden est arrêté"
        echo "Vaultwarden est arrêté."
    fi
}

case "${1:-none}" in
    start) start_vaultwarden ;;
    stop) stop_vaultwarden ;;
    restart) restart_vaultwarden ;;
    update) update_vaultwarden ;;
    status) status_vaultwarden ;;
    *)
        echo "Usage : vaultwarden {start|stop|restart|update|status}"
        exit 1
        ;;
esac
EOF

    chmod +x "$COMMAND_PATH"
    log "+" "Commande Vaultwarden installée : $COMMAND_PATH"
}

# === 7. Déploiement du conteneur Vaultwarden ===
create_vaultwarden() {
    check_docker
    log "~" "Initialisation du conteneur Vaultwarden..."

    mkdir -p "$vaultwarden_data" >/dev/null 2>&1 || true

    if docker ps -a --format '{{.Names}}' | grep -q "^vaultwarden$"; then
        log "~" "Conteneur existant détecté : suppression"
        docker rm -f vaultwarden >/dev/null 2>&1 || true
    fi

    if docker run -d \
        --name vaultwarden \
        --restart unless-stopped \
        -v "$vaultwarden_data:/data" \
        -p "${vaultwarden_port}:80" \
        vaultwarden/server:latest >/dev/null 2>&1; then
        log "+" "Vaultwarden créé et démarré avec succès"
    else
        log "[-]" "Échec lors de la création du conteneur Vaultwarden"
        exit 1
    fi

    install_vaultwarden_command
}

# Exécution principale
create_vaultwarden

log "✓" "Fin du programme Cerbere-VaultWarden"
