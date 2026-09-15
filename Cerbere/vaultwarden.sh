#!/bin/bash
exec 1>/dev/null
set -euo pipefail

Programme="Cerbere-VaultWarden"

# === Chargement des credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
fi

# === LOG SYSTEM === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Début du programme"

# --- Vérification root ---
if [[ $EUID -ne 0 ]]; then
    log "[-] Ce script doit être exécuté en tant que root."
    exit 1
fi
log "[+] Droits root confirmés"

# --- Valeurs par défaut ---
DEFAULT_PORT=1013
DEFAULT_PATH="/media/Runable/Docker/VaultWarden"

# --- Récupération des variables avec fallback ---
vaultwarden_port="${PORT_VAULTWARDEN:-$DEFAULT_PORT}"
vaultwarden_data="${PATH_VAULTWARDEN:-$DEFAULT_PATH}"

log "[~] Port utilisé : $vaultwarden_port"
log "[~] Chemin utilisé : $vaultwarden_data"

# --- Installation Docker si absent ---
install_docker() {
    log "[~] Installation de Docker..."

    apt update -y >/dev/null 2>&1 || { log "[-] Impossible de mettre à jour apt"; exit 1; }
    apt install -y ca-certificates curl gnupg lsb-release >/dev/null 2>&1 \
        || { log "[-] Impossible d’installer les dépendances Docker"; exit 1; }

    install -m 0755 -d /etc/apt/keyrings >/dev/null 2>&1
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1 \
        || { log "[-] Impossible de récupérer la clé Docker"; exit 1; }

    chmod a+r /etc/apt/keyrings/docker.gpg >/dev/null 2>&1

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    apt update -y >/dev/null 2>&1 || { log "[-] Impossible de mettre à jour apt après ajout du dépôt Docker"; exit 1; }

    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 \
        || { log "[-] Impossible d’installer Docker"; exit 1; }

    log "[+] Docker installé avec succès"
}

# --- Vérification Docker ---
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[~] Docker absent : installation"
        install_docker
    else
        log "[+] Docker déjà installé"
    fi
}

# --- Création de Vaultwarden ---
create_vaultwarden() {
    check_docker
    log "[~] Création de Vaultwarden..."

    mkdir -p "$vaultwarden_data"

    if docker ps -a --format '{{.Names}}' | grep -q "^vaultwarden$"; then
        log "[~] Conteneur existant détecté : suppression"
        docker rm -f vaultwarden >/dev/null 2>&1 || true
    fi

    docker run -d \
        --name vaultwarden \
        --restart unless-stopped \
        -v "$vaultwarden_data:/data" \
        -p "${vaultwarden_port}:80" \
        vaultwarden/server:latest

    log "[+] Vaultwarden créé et démarré"
    install_vaultwarden_command
}

# --- Installation de la commande vaultwarden ---
install_vaultwarden_command() {
    log "[~] Installation de la commande vaultwarden"

    COMMAND_PATH="/usr/local/bin/vaultwarden"

    cat > "$COMMAND_PATH" << 'EOF'
#!/bin/bash
set -euo pipefail

Programme="Cerbere-VaultWarden"

# === Chargement credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"

if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
else
    PATH_MNEMOSYNE=""
fi

# === LOG SYSTEM === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
fi

LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Variables avec fallback === #
VAULTWARDEN_PORT="${PORT_VAULTWARDEN:-1013}"
VAULTWARDEN_DATA="${PATH_VAULTWARDEN:-/media/Runable/Docker/VaultWarden}"

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[-] Docker n'est pas installé"
        exit 1
    fi
}

start_vaultwarden() {
    check_docker
    docker start vaultwarden >/dev/null 2>&1 \
        && log "[+] Vaultwarden démarré" \
        || log "[-] Impossible de démarrer Vaultwarden"
}

stop_vaultwarden() {
    check_docker
    docker stop vaultwarden >/dev/null 2>&1 \
        && log "[+] Vaultwarden arrêté" \
        || log "[-] Impossible d'arrêter Vaultwarden"
}

restart_vaultwarden() {
    check_docker
    docker restart vaultwarden >/dev/null 2>&1 \
        && log "[+] Vaultwarden redémarré" \
        || log "[-] Impossible de redémarrer Vaultwarden"
}

update_vaultwarden() {
    check_docker
    log "[~] Mise à jour Vaultwarden..."

    docker pull vaultwarden/server:latest >/dev/null 2>&1 \
        || { log "[-] Impossible de télécharger la nouvelle image"; exit 1; }

    docker rm -f vaultwarden >/dev/null 2>&1 || true
    log "[~] Ancien conteneur supprimé"

    mkdir -p "$VAULTWARDEN_DATA"

    docker run -d \
        --name vaultwarden \
        --restart unless-stopped \
        -v "$VAULTWARDEN_DATA:/data" \
        -p "${VAULTWARDEN_PORT}:80" \
        vaultwarden/server:latest \
        >/dev/null 2>&1 \
        || { log "[-] Impossible de recréer Vaultwarden"; exit 1; }

    log "[+] Vaultwarden mis à jour et recréé"
}

status_vaultwarden() {
    if docker ps | grep -q vaultwarden; then
        log "[+] Vaultwarden est en cours d'exécution"
        echo "Vaultwarden est en cours d'exécution"
    else
        log "[~] Vaultwarden est arrêté"
        echo "Vaultwarden est arrêté"
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
    log "[+] Commande vaultwarden installée"
}

# --- Exécution ---
create_vaultwarden

log "[✓] Fin du programme"
