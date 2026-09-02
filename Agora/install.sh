#!/bin/bash

exec 1>/dev/null
set -euo pipefail

# === Vérification des droits administrateurs === #
if [[ $EUID -ne 0 ]]; then
    echo "Droits insuffisants : exécuter ce script en tant que root." >&2
    exit 1
fi

# === Définition des variables === #
BASE_DIR="/etc/AubeZero"
LOG_DIR="$BASE_DIR/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Agora-Install"
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main"
MODULES=(Cerbere Apollon Athena Hades Hermes Promethee)
DL_FAIL=0

# === Création du dossier de log === #
mkdir -p "$LOG_DIR"

# === Fonction de log === #
log() {
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "$LOG_FILE"
}

# === Création des dossiers === #
log "Création des dossiers : PENDING"

mkdir -p "$BASE_DIR/Agora"
for mod in "${MODULES[@]}"; do
    mkdir -p "$BASE_DIR/$mod"
done

log "Création des dossiers : SUCCESS"

# === Téléchargement des installateurs === #
log "Téléchargement des installateurs : PENDING"

for mod in "${MODULES[@]}"; do
    TARGET="$BASE_DIR/$mod/install.sh"
    URL="$BASE_URL/$mod/install.sh"

    if ! curl --fail --silent --show-error -o "$TARGET" "$URL"; then
        DL_FAIL=1
    else
        chmod 700 "$TARGET"
    fi
done

if [[ $DL_FAIL -eq 1 ]]; then
    log "Téléchargement des installateurs : FAILED"
    exit 1
fi

log "Téléchargement des installateurs : SUCCESS"

# === Mise à jour du système === #
log "Mise à jour du système : PENDING"

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get full-upgrade -y -qq
apt-get autoremove -y --purge -qq
apt-get autoclean -y -qq

log "Mise à jour du système : SUCCESS"

# === Installation des programmes === #
log "Installation des programmes : PENDING"

apt-get install -y -qq ca-certificates curl gnupg software-properties-common

install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
> /etc/apt/sources.list.d/docker.list

add-apt-repository ppa:deadsnakes/ppa -y >/dev/null 2>&1

apt-get update -qq
apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    webp imagemagick ffmpeg unzip p7zip-full unrar \
    git net-tools iperf samba python3 python3-pip

log "Installation des programmes : SUCCESS"

# === Modification des alias === #
log "Modification des alias : PENDING"

BASHRC_URL="$BASE_URL/Agora/.bashrc"
BASHRC_LOCAL="$BASE_DIR/Agora/.bashrc"

if curl --fail --silent --show-error -o "$BASHRC_LOCAL" "$BASHRC_URL"; then
    cp -f "$BASHRC_LOCAL" /root/.bashrc

    for user_dir in /home/*; do
        [[ -d "$user_dir" ]] || continue
        user=$(basename "$user_dir")
        cp -f "$BASHRC_LOCAL" "$user_dir/.bashrc"
        chown "$user:$user" "$user_dir/.bashrc"
    done

    log "Modification des alias : SUCCESS"
else
    log "Modification des alias : FAILED (download)"
fi

# === Désactivation de la veille === #
log "Désactivation de la veille : PENDING"

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1

mkdir -p /etc/systemd/sleep.conf.d
cat <<EOF > /etc/systemd/sleep.conf.d/nosuspend.conf
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF

if [[ -f /etc/gdm3/greeter.dconf-defaults ]] && \
   ! grep -q 'sleep-inactive-ac-type="blank"' /etc/gdm3/greeter.dconf-defaults; then
    echo 'sleep-inactive-ac-type="blank"' >> /etc/gdm3/greeter.dconf-defaults
fi

log "Désactivation de la veille : SUCCESS"

# === Montage des disques === #
log "Montage des disques : PENDING"

lsblk -pbno NAME,FSTYPE,LABEL,UUID,MOUNTPOINT | while read -r DEV FSTYPE LABEL UUID MOUNT; do
    [[ -n "$FSTYPE" && "$FSTYPE" != "swap" && -z "$MOUNT" ]] || continue

    MOUNT_NAME="${LABEL:-$UUID}"
    [[ -n "$MOUNT_NAME" ]] || continue

    MOUNT_DIR="/media/$MOUNT_NAME"
    mkdir -p "$MOUNT_DIR"

    IDENTIFIER="${UUID:+UUID=$UUID}"
    IDENTIFIER="${IDENTIFIER:-$DEV}"

    if ! grep -q "$MOUNT_DIR" /etc/fstab && ! grep -q "$IDENTIFIER" /etc/fstab; then
        echo "$IDENTIFIER  $MOUNT_DIR  $FSTYPE  defaults,nofail,x-systemd.device-timeout=5  0  2" >> /etc/fstab
    fi

    mount "$MOUNT_DIR" >/dev/null 2>&1 || mount "$DEV" "$MOUNT_DIR" >/dev/null 2>&1
done

systemctl daemon-reload >/dev/null 2>&1
mount -a >/dev/null 2>&1

log "Montage des disques : SUCCESS"

# === Lancement des sous-modules === #
log "Exécution des installateurs : PENDING"

for mod in "${MODULES[@]}"; do
    SCRIPT="$BASE_DIR/$mod/install.sh"

    if [[ -f "$SCRIPT" ]]; then
        log "Lancement de $mod : PENDING"
        if bash "$SCRIPT" >/dev/null 2>&1; then
            log "Lancement de $mod : SUCCESS"
        else
            log "Lancement de $mod : FAILED"
        fi
    else
        log "Script $mod introuvable : SKIPPED"
    fi
done

log "Exécution des installateurs : SUCCESS"

# === Installation du docker LAMP === #
log "Installation du Docker LAMP : PENDING"

docker rm -f lamp >/dev/null 2>&1 || true
docker pull php:8.2-apache

docker run -d \
    --name lamp \
    --restart=unless-stopped \
    -e TZ=CET \
    -v "$PathLamp:/var/www/html" \
    -v "$PathPmTiles:/var/www/html/europe.pmtiles:ro" \
    -v /media/:/media \
    -p "$PortLamp:80" \
    -p 3306:3306 \
    php:8.2-apache

log "Installation du Docker LAMP : SUCCESS"
