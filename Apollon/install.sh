#!/bin/sh
# AubeZero - Master Installer
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installateur maître AubeZero (Cerbere, Apollon, Hermes, Agora, Hades)

# Stop en cas d'erreur ou de variable non définie
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

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-AUBEZERO-INSTALLER.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Démarrage de l'installateur maître AubeZero"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Création de l'arborescence AubeZero ===
mkdir -p "$BASE_DIR/Apollon"
mkdir -p "$BASE_DIR/Hermes"
mkdir -p "$BASE_DIR/Agora"
mkdir -p "$BASE_DIR/Hades"

log "+" "Arborescence AubeZero créée"

# === 5. Installation des dépendances globales ===
install_dep() {
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

install_dep "curl"
install_dep "git"
install_dep "jq"

log "+" "Dépendances globales installées"

# === 6. Téléchargement / Mise à jour du dépôt AubeZero ===
AUBEZERO_GITHUB="https://github.com/ROYJohan08/AubeZero.git"
AUBEZERO_LOCAL="$BASE_DIR/AubeZeroRepo"

if [ ! -d "$AUBEZERO_LOCAL/.git" ]; then
    log "~" "Clonage du dépôt AubeZero..."
    if git clone "$AUBEZERO_GITHUB" "$AUBEZERO_LOCAL" >/dev/null 2>&1; then
        log "+" "Dépôt AubeZero cloné avec succès"
    else
        log "[-]" "Échec du clonage du dépôt AubeZero"
        exit 1
    fi
else
    log "~" "Mise à jour du dépôt AubeZero..."
    if git -C "$AUBEZERO_LOCAL" pull >/dev/null 2>&1; then
        log "+" "Dépôt AubeZero mis à jour avec succès"
    else
        log "[-]" "Échec de la mise à jour du dépôt AubeZero"
    fi
fi

# === 7. Installation des modules Cerbere ===
install_module() {
    _module="$1"
    _script="$AUBEZERO_LOCAL/Cerbere/${_module}.sh"

    if [ -f "$_script" ]; then
        log "~" "Installation du module : $_module"
        if sh "$_script"; then
            log "+" "Module installé avec succès : $_module"
        else
            log "[-]" "Erreur lors de l'exécution du script module : $_module"
        fi
    else
        log "[-]" "Script du module introuvable : $_script"
    fi
}

MODULES="cerbere-duress cerbere-watchdog cerbere-glancews cerbere-portainer cerbere-vaultwarden cerbere-siyuan cerbere-kolibri cerbere-kiwix cerbere-gitea"

for m in $MODULES; do
    install_module "$m"
done

log "✓" "Tous les modules Cerbere ont été traités"

# === 8. Installation des commandes globales ===
install_cmd() {
    _cmd="$1"
    _script="$AUBEZERO_LOCAL/Commands/${_cmd}.sh"

    if [ -f "$_script" ]; then
        cp "$_script" "/usr/bin/${_cmd}"
        chmod +x "/usr/bin/${_cmd}"
        log "+" "Commande installée : /usr/bin/${_cmd}"
    else
        log "[-]" "Fichier de commande introuvable : $_script"
    fi
}

COMMANDS="duress watchdog glances portainer vaultwarden siyuan kolibri kiwix gitea"

for c in $COMMANDS; do
    install_cmd "$c"
done

log "✓" "Commandes globales installées"

# === 9. Fin d'exécution ===
log "✓" "Installation complète AubeZero terminée"
