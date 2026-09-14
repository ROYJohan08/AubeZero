#!/bin/bash
set -euo pipefail

Programme="Cerbere-VaultWarden"
LOG_DIR="/etc/AubeZero/Mnemosyne/"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"
# --- Function de logs ---
log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}
# --- Vérification root ---
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi
# --- Valeurs par défaut ---
DEFAULT_PORT=1013
DEFAULT_PATH="/media/Runable/Docker/VaultWarden"
# --- Chargement des credentials ---
CRED_FILE="/etc/AubeZero/Cerbere/credentials.env"
if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
    log "[~] credentials.env chargé."
else
    log "[!] credentials.env introuvable, utilisation des valeurs par défaut."
fi
# --- Récupération des variables avec fallback ---
vaultwarden_port="${PORT_VAULTWARDEN:-$DEFAULT_PORT}"
vaultwarden_data="${PATH_VAULTWARDEN:-$DEFAULT_PATH}"
log "[~] Port utilisé : $vaultwarden_port"
log "[~] Chemin utilisé : $vaultwarden_data"
# --- Vérification Docker ---
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[-] Docker n'est pas installé."
        echo "Docker n'est pas installé."
        exit 1
    fi
}
# --- Création de Vaultwarden ---
create_vaultwarden() {
    check_docker
    log "[~] Création de Vaultwarden..."
    mkdir -p "$vaultwarden_data"
    docker run -d \
        --name vaultwarden \
        --restart unless-stopped \
        -v "$vaultwarden_data:/data" \
        -p "${vaultwarden_port}:80" \
        vaultwarden/server:latest
    log "[+] Vaultwarden créé et démarré."
    install_vaultwarden_command
}
# --- Installation de la commande vaultwarden ---
install_vaultwarden_command() {
    COMMAND_PATH="/usr/local/bin/vaultwarden"
    cat > "$COMMAND_PATH" << 'EOF'
#!/bin/bash
set -euo pipefail
log() {
    Programme="Cerbere-VaultWarden"
    mkdir -p "/etc/AubeZero/Mnemosyne/" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "/etc/AubeZero/Mnemosyne/$(date +%Y-%m).log"
}
check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "[-] Docker n'est pas installé."
        exit 1
    fi
}
start_vaultwarden() {
    check_docker
    docker start vaultwarden >/dev/null 2>&1 \
        && log "[+] Vaultwarden démarré." \
        || log "[-] Impossible de démarrer Vaultwarden."
}
stop_vaultwarden() {
    check_docker
    docker stop vaultwarden >/dev/null 2>&1 \
        && log "[+] Vaultwarden arrêté." \
        || log "[-] Impossible d'arrêter Vaultwarden."
}
restart_vaultwarden() {
    check_docker
    docker restart vaultwarden >/dev/null 2>&1 \
        && log "[+] Vaultwarden redémarré." \
        || log "[-] Impossible de redémarrer Vaultwarden."
}
update_vaultwarden() {
    check_docker
    log "[~] Mise à jour Vaultwarden..."
    docker pull vaultwarden/server:latest
    docker rm -f vaultwarden >/dev/null 2>&1 || true
    log "[+] Nouvelle image téléchargée."
}
status_vaultwarden() {
    if docker ps | grep -q vaultwarden; then
        log "[+] Vaultwarden est en cours d'exécution."
        echo "Vaultwarden est en cours d'exécution."
    else
        log "[~] Vaultwarden est arrêté."
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
    log "[+] Commande vaultwarden installée."
}
# --- Exécution ---
create_vaultwarden
log "[✓] Installation complète."
