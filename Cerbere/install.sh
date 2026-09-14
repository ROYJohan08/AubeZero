#!/bin/bash
set -euo pipefail

Programme="Cerbere-Installer"
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="${LOG_DIR}/$(date +%Y-%m).log"

# --- Fonction de logs ---
log() {
    mkdir -p "$LOG_DIR" >/dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "$LOG_FILE"
}

log "[👉] Démarrage de l'installateur Cerbere"

# === Vérification root === #
if [[ $EUID -ne 0 ]]; then
    log "[-] Ce script doit être exécuté en root"
    exit 1
fi
log "[+] Droits root confirmés"

# === Dossier Cerbere === #
CERBERE_DIR="/etc/AubeZero/Cerbere"
mkdir -p "$CERBERE_DIR"

# === URL GitHub === #
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/main/Cerbere"

# === Liste des modules à installer (ordre obligatoire) === #
MODULES=(
    "credentials.env"      # Toujours en premier
    "duress.sh"
    "vaultwarden.sh"
    "portainer.sh"
    "glancews.sh"
    "watchdog.sh"
)

# === Fonction : Vérifier version GitHub et installer === #
install_module() {
    local module="$1"
    local local_path="$CERBERE_DIR/$module"
    local remote_url="$BASE_URL/$module"
    local tmp_file="/tmp/$module.new"

    log "[~] Vérification du module : $module"

    # Télécharger la version GitHub
    if ! curl -fsSL "$remote_url" -o "$tmp_file"; then
        log "[-] Impossible de récupérer $module depuis GitHub"
        return
    fi

    # Si le module n'existe pas → installation directe
    if [[ ! -f "$local_path" ]]; then
        cp "$tmp_file" "$local_path"
        chmod +x "$local_path" 2>/dev/null || true
        log "[+] Module $module installé (nouveau)"
        return
    fi

    # Comparaison SHA256
    local local_hash
    local remote_hash
    local_hash=$(sha256sum "$local_path" | awk '{print $1}')
    remote_hash=$(sha256sum "$tmp_file" | awk '{print $1}')

    if [[ "$local_hash" != "$remote_hash" ]]; then
        cp "$tmp_file" "$local_path"
        chmod +x "$local_path" 2>/dev/null || true
        log "[+] Module $module mis à jour (version GitHub plus récente)"
    else
        log "[=] Module $module déjà à jour"
    fi
}

# === Installation de tous les modules === #
for module in "${MODULES[@]}"; do
    install_module "$module"
done

# === Exécution automatique des modules === #
log "[~] Exécution des modules installés"

for module in "${MODULES[@]}"; do
    MODULE_PATH="$CERBERE_DIR/$module"

    # credentials.env → ne pas exécuter
    if [[ "$module" == "credentials.env" ]]; then
        log "[=] credentials.env chargé (pas d'exécution)"
        continue
    fi

    if [[ -f "$MODULE_PATH" ]]; then
        log "[~] Lancement : $module"
        bash "$MODULE_PATH"
    else
        log "[-] Module introuvable : $module"
    fi
done

log "[✓] Installation complète de Cerbere et des modules"
