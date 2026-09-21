#!/bin/sh
# Cerbere - Credential
# @Author : ROYJohan
# @Version : 1.0.0
# @Date : 2026-09-21
# @Desc : Script de récupération, de vérification et de synchronisation du fichier credentials.env

# Stop en cas d'erreur ou de variable non définie
set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Droits insuffisants : exécution non-root" >&2
    exit 1
fi

# === 2. Répertoires et fichiers de configuration ===
BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CRED_FILE="$CERBERE_DIR/credentials.env"

mkdir -p "$CERBERE_DIR"

# Chargement préalable si le fichier existe déjà pour récupérer PATH_MNEMOSYNE et BASE_URL
if [ -f "$CRED_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CRED_FILE"
fi

# Valeurs par défaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/ROYJohan08/AubeZero/main}/Cerbere/credentials.env"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-CREDENTIAL.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du programme Cerbere-Credential"

# Redirection de stdout globale vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Vérification et recherche du fichier credentials.env ===
if [ ! -f "$CRED_FILE" ]; then
    log "~" "Fichier credentials.env introuvable dans Cerbere : recherche de copies locales"
    
    # Recherche d'un fichier credentials.env existant ailleurs sur le système
    RECENT_CREDENTIALS=$(find /etc /var /home /root -type f -name "credentials.env" 2>/dev/null | head -n 1)
    
    if [ -n "${RECENT_CREDENTIALS:-}" ] && [ -f "$RECENT_CREDENTIALS" ]; then
        cp "$RECENT_CREDENTIALS" "$CRED_FILE"
        log "+" "Copie locale récupérée depuis $RECENT_CREDENTIALS"
    else
        log "~" "Aucune copie locale trouvée : tentative de téléchargement distant"
        if curl --fail --silent --show-error -o "$CRED_FILE" "$BASE_URL" 2>/dev/null; then
            log "+" "Fichier modele récupéré depuis le dépôt distant"
            log "~" "Veuillez renseigner les valeurs réelles dans $CRED_FILE"
        else
            log "[-]" "Téléchargement distant impossible et aucun fichier local trouvé"
            echo "[-] Erreur critique : credentials.env introuvable." >&2
            exit 1
        fi
    fi
    
    chown root:root "$CRED_FILE" 2>/dev/null || true
    chmod 600 "$CRED_FILE" 2>/dev/null || true
    log "+" "Permissions de sécurité (600) appliquées sur $CRED_FILE"
fi

# === 5. Chargement des variables ===
if [ -f "$CRED_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CRED_FILE"
    log "+" "Variables de configuration chargées"
else
    log "[-]" "Credentials introuvables après la procédure de récupération : arrêt"
    echo "[-] Erreur : Impossible de charger credentials.env" >&2
    exit 1
fi

# === 6. Synchronisation des clés distantes (Hybride / Non bloquant) ===
log "~" "Vérification des mises à jour des clés de configuration"
TMP_GITHUB="/tmp/credentials_github.env"

if curl --fail --silent --show-error -o "$TMP_GITHUB" "$BASE_URL" 2>/dev/null; then
    log "+" "Fichier modèle distant téléchargé pour comparaison"
    
    # Lecture ligne par ligne pour ajouter les nouvelles clés sans écraser les valeurs locales
    while IFS= read -r line || [ -n "$line" ]; do
        # Ignorer les lignes vides et les commentaires
        case "$line" in
            ''|\#*) continue ;;
        esac
        
        var_name="${line%%=*}"
        if ! grep -q "^${var_name}=" "$CRED_FILE"; then
            echo "$line" >> "$CRED_FILE"
            log "+" "Nouvelle variable de configuration ajoutée : $var_name"
        fi
    done < "$TMP_GITHUB"
    
    rm -f "$TMP_GITHUB"
    log "+" "Synchronisation terminée avec succès"
else
    log "~" "Mode hors-ligne ou réseau indisponible : étape de synchronisation ignorée"
fi

log "✓" "Fin du programme Cerbere-Credential"
