#!/bin/bash
# install.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 14:00
# @Desc : Installateur maître AubeZero (Cerbere, Apollon, Hermes, Agora, Hades)

set -euo pipefail

Programme="AubeZero-Installer"

# === Vérification root === #
if [[ $EUID -ne 0 ]]; then
    echo "[-] Ce script doit être exécuté en root."
    exit 1
fi

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

mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

log() {
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Démarrage de l’installateur maître AubeZero"

# === Dossiers AubeZero === #
mkdir -p /etc/AubeZero
mkdir -p /etc/AubeZero/Cerbere
mkdir -p /etc/AubeZero/Apollon
mkdir -p /etc/AubeZero/Hermes
mkdir -p /etc/AubeZero/Agora
mkdir -p /etc/AubeZero/Hades

log "[+] Arborescence AubeZero créée"

# === Dépendances globales === #
install_dep() {
    if command -v "$1" >/dev/null 2>&1; then
        log "[=] Dépendance OK : $1"
        return
    fi

    log "[~] Installation dépendance : $1"
    apt-get update -qq
    apt-get install -y -qq "$1"
}

install_dep "curl"
install_dep "git"
install_dep "jq"
install_dep "docker.io"

log "[+] Dépendances globales installées"

# === Téléchargement du dépôt AubeZero === #
AUBEZERO_GITHUB="https://github.com/ROYJohan08/AubeZero.git"
AUBEZERO_LOCAL="/etc/AubeZero/AubeZeroRepo"

if [[ ! -d "$AUBEZERO_LOCAL/.git" ]]; then
    log "[~] Clonage du dépôt AubeZero"
    git clone "$AUBEZERO_GITHUB" "$AUBEZERO_LOCAL" >/dev/null 2>&1 \
        && log "[+] Dépôt cloné" \
        || { log "[-] Échec clonage dépôt"; exit 1; }
else
    log "[~] Mise à jour du dépôt AubeZero"
    git -C "$AUBEZERO_LOCAL" pull >/dev/null 2>&1 \
        && log "[+] Dépôt mis à jour" \
        || log "[−] Échec mise à jour dépôt"
fi

# === Installation des modules Cerbere === #
install_module() {
    local module="$1"
    local script="/etc/AubeZero/AubeZeroRepo/Cerbere/${module}.sh"

    if [[ -f "$script" ]]; then
        log "[~] Installation module : $module"
        bash "$script"
        log "[+] Module installé : $module"
    else
        log "[-] Module introuvable : $module"
    fi
}

MODULES=(
    "cerbere-duress"
    "cerbere-watchdog"
    "cerbere-glancews"
    "cerbere-portainer"
    "cerbere-vaultwarden"
    "cerbere-siyuan"
    "cerbere-kolibri"
    "cerbere-kiwix"
    "cerbere-gitea"
)

for m in "${MODULES[@]}"; do
    install_module "$m"
done

log "[✓] Tous les modules Cerbere installés"

# === Installation des commandes globales === #
install_cmd() {
    local cmd="$1"
    local script="/etc/AubeZero/AubeZeroRepo/Commands/${cmd}.sh"

    if [[ -f "$script" ]]; then
        cp "$script" "/usr/bin/${cmd}"
        chmod +x "/usr/bin/${cmd}"
        log "[+] Commande installée : $cmd"
    else
        log "[-] Commande introuvable : $cmd"
    fi
}

COMMANDS=(
    "duress"
    "watchdog"
    "glances"
    "portainer"
    "vaultwarden"
    "siyuan"
    "kolibri"
    "kiwix"
    "gitea"
)

for c in "${COMMANDS[@]}"; do
    install_cmd "$c"
done

log "[✓] Commandes globales installées"

# === Fin === #
log "[✓] Installation complète AubeZero terminée"
echo "[✓] Installation complète AubeZero terminée"
