#!/bin/sh
# Cerbere - Install
# @Author : ROYJohan
# @Version : 1.0.0
# @Date : 2026-09-21
# @Desc : Installateur et gestionnaire des modules de sécurité Cerbere

# Stop en cas d'erreur ou de variable non définie
set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Ce script doit être exécuté en tant que root." >&2
    exit 1
fi

# === 2. Repertoires et configuration Cerbere ===
BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

mkdir -p "$CERBERE_DIR"

# Chargement dynamique des variables si credentials.env existe
if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# Valeurs par défaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/ROYJohan08/AubeZero/main}/Cerbere"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-INSTALL.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Démarrage de l'installateur Cerbere"

# Redirection de stdout globale vers les logs Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Liste des modules à traiter ===
MODULES="credentials.env duress.sh vaultwarden.sh portainer.sh glancews.sh watchdog.sh"

# === 5. Fonction de vérification et mise à jour hybride ===
install_module() {
    _module="$1"
    _local_path="$CERBERE_DIR/$_module"
    _remote_url="$BASE_URL/$_module"
    _tmp_file="/tmp/$_module.new"

    log "~" "Vérification du module : $_module"

    # Tentative de téléchargement depuis GitHub
    if curl -fsSL "$_remote_url" -o "$_tmp_file" 2>/dev/null; then
        # Si le fichier local n'existe pas -> Nouvelle installation
        if [ ! -f "$_local_path" ]; then
            cp "$_tmp_file" "$_local_path"
            [ "$_module" != "credentials.env" ] && chmod 700 "$_local_path"
            log "+" "Module $_module installé (nouvelle version distante)"
            rm -f "$_tmp_file"
            return 0
        fi

        # Comparaison par somme de contrôle SHA256
        _local_hash=$(sha256sum "$_local_path" | awk '{print $1}')
        _remote_hash=$(sha256sum "$_tmp_file" | awk '{print $1}')

        if [ "$_local_hash" != "$_remote_hash" ]; then
            cp "$_tmp_file" "$_local_path"
            [ "$_module" != "credentials.env" ] && chmod 700 "$_local_path"
            log "+" "Module $_module mis à jour (différence SHA256 détectée)"
        else
            log "=" "Module $_module déjà à jour"
        fi
        rm -f "$_tmp_file"
    else
        # En cas d'échec réseau / mode hors-ligne
        if [ -f "$_local_path" ]; then
            log "~" "Réseau indisponible : conservation de la version locale de $_module"
        else
            log "[-]" "Impossible de récupérer $_module et aucune copie locale disponible"
        fi
    fi
}

# === 6. Traitement des modules ===
for module in $MODULES; do
    install_module "$module"
done

# === 7. Exécution séquentielle des scripts ===
log "~" "Exécution des sous-modules de Cerbere"

for module in $MODULES; do
    MODULE_PATH="$CERBERE_DIR/$module"

    # Ne pas exécuter credentials.env
    if [ "$module" = "credentials.env" ]; then
        if [ -f "$MODULE_PATH" ]; then
            # shellcheck disable=SC1090
            . "$MODULE_PATH"
            log "=" "Fichier credentials.env chargé avec succès"
        fi
        continue
    fi

    if [ -f "$MODULE_PATH" ]; then
        log "👉" "Lancement de : $module"
        if sh "$MODULE_PATH" >> "$LOG_FILE" 2>&1; then
            log "+" "Module $module exécuté avec succès"
        else
            log "[-]" "Échec lors de l'exécution de $module"
        fi
    else
        log "[-]" "Module introuvable : $module"
    fi
done

log "✓" "Installation et initialisation de Cerbere terminées"
