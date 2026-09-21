#!/bin/sh
# Hades - DDay
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Urgence et effacement sécurisé des disques et données pour AubeZero

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

if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# Valeurs par défaut
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
BASE_MEDIA="/media"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-HADES-DDAY.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début de la procédure d'urgence Hades-DDay"

# Redirection globale de stdout vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Vérification des outils nécessaires ===
check_dep() {
    _pkg="$1"
    if ! command -v "$_pkg" >/dev/null 2>&1; then
        log "~" "Installation de la dépendance requise : $_pkg"
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq "$_pkg" >/dev/null 2>&1
        fi
    fi
}

check_dep "lsblk"
check_dep "sed"

# === 5. Parcours et effacement sécurisé des disques cibles ===
log "~" "Analyse des points de montage sous $BASE_MEDIA..."

for dir in "$BASE_MEDIA"/*; do
    [ -d "$dir" ] || continue

    name=$(basename "$dir")

    # Ignorer les fichiers/dossiers cachés
    case "$name" in
        .*) continue ;;
    esac

    # Filtrage POSIX des points de montage concernés
    case "$name" in
        Films*|Series*|Docs*)
            log "~" "Cible identifiée : $name ($dir)"
            
            raw_disk=$(lsblk -no PKNAME "$dir" 2>/dev/null | head -n1)
            if [ -z "$raw_disk" ]; then
                raw_disk=$(lsblk -no KNAME "$dir" 2>/dev/null | head -n1)
            fi

            if [ -z "$raw_disk" ]; then
                log "[-]" "Impossible de déterminer le périphérique bloc pour $dir"
                continue
            fi

            clean_disk=$(echo "$raw_disk" | sed -E 's/p?[0-9]+$//')
            disk="/dev/$clean_disk"

            if [ ! -b "$disk" ]; then
                log "[-]" "Périphérique bloc invalide : $disk"
                continue
            fi

            log "~" "Exécution de l'effacement sur $disk..."

            case "$disk" in
                /dev/nvme*)
                    if command -v nvme >/dev/null 2>&1; then
                        nvme sanitize "$disk" --sanact=2 --ause=1 --owpass=1 || log "[-]" "Échec de la commande nvme sanitize sur $disk"
                    else
                        log "[-]" "Outil nvme-cli absent pour traiter $disk"
                    fi
                    ;;
                *)
                    if command -v hdparm >/dev/null 2>&1; then
                        hdparm --user-master u --security-set-pass p "$disk" || true
                        hdparm --user-master u --security-erase p "$disk" || log "[-]" "Échec de la commande hdparm erase sur $disk"
                    else
                        log "[-]" "Outil hdparm absent pour traiter $disk"
                    fi
                    ;;
            esac
            ;;
        *)
            ;;
    esac
done

# === 6. Nettoyage du répertoire temporaire DownBox ===
DOWNBOX_DIR="/media/Runable/DownBox"
if [ -d "$DOWNBOX_DIR" ]; then
    log "~" "Purge du répertoire : $DOWNBOX_DIR"
    rm -rf "${DOWNBOX_DIR:?}"/*
    log "+" "Purge de $DOWNBOX_DIR terminée"
fi

log "✓" "Procédure d'urgence Hades-DDay exécutée avec succès"
