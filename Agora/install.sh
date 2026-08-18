#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi
set -e
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Agora-Install"
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main"
mkdir -p "$LOG_DIR" > /dev/null

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Création des dossiers : PENDING" >> "$LOG_FILE"
mkdir -p /etc/AubeZero/{Agora,Apollon,Athena,Cerbere,Hades,Hermes,Promethee} > /dev/null
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Création des dossiers : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des installateurs : PENDING" >> "$LOG_FILE"
MODULES_DOWNLOAD=("Apollon" "Athena" "Cerbere" "Hades" "Hermes" "Promethee")
DL_FAIL=0
for mod in "${MODULES_DOWNLOAD[@]}"; do
    if ! wget -q -N "$BASE_URL/$mod/install.sh" -O "/etc/AubeZero/$mod/install.sh"; then
        DL_FAIL=1
    fi
done
if [ "$DL_FAIL" -eq 1 ]; then
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des installateurs : FAILED" >> "$LOG_FILE"
    echo "Erreur : Échec lors du téléchargement d'un ou plusieurs installateurs." >&2
    exit 1
fi
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des installateurs : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Mise a jours du système : PENDING" >> "$LOG_FILE"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y -qq > /dev/null
apt-get upgrade -y -qq > /dev/null
apt-get full-upgrade -y -qq > /dev/null
apt-get autoclean -y -qq > /dev/null
apt-get autoremove -y --purge -qq > /dev/null
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Mise a jours du système : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation des programmes : PENDING" >> "$LOG_FILE"
apt-get install -y -qq ca-certificates curl gnupg software-properties-common > /dev/null
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
add-apt-repository ppa:deadsnakes/ppa -y > /dev/null 2>&1
apt-get update -y -qq > /dev/null
apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    git net-tools iperf samba python3 python3-pip > /dev/null
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation des programmes : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Modification des alias : PENDING" >> "$LOG_FILE"
if wget -q -N "$BASE_URL/Agora/.bashrc" -O /etc/AubeZero/Agora/.bashrc; then
    cp -f /etc/AubeZero/Agora/.bashrc /root/.bashrc
    for user_dir in /home/*; do
        if [ -d "$user_dir" ]; then
            username=$(basename "$user_dir")
            cp -f /etc/AubeZero/Agora/.bashrc "$user_dir/.bashrc"
            chown "$username:$username" "$user_dir/.bashrc"
        fi
    done
else
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-Modification des alias : FAILED (wget error)" >> "$LOG_FILE"
fi
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Modification des alias : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Désactivation de la veille : PENDING" >> "$LOG_FILE"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target > /dev/null 2>&1
mkdir -p /etc/systemd/sleep.conf.d > /dev/null
cat <<EOF > /etc/systemd/sleep.conf.d/nosuspend.conf
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF
if [ -f /etc/gdm3/greeter.dconf-defaults ]; then
    if ! grep -q 'sleep-inactive-ac-type="blank"' /etc/gdm3/greeter.dconf-defaults; then
        echo 'sleep-inactive-ac-type="blank"' >> /etc/gdm3/greeter.dconf-defaults
    fi
fi
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Désactivation de la veille : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Montage des disques : PENDING" >> "$LOG_FILE"
lsblk -pbno NAME,FSTYPE,LABEL,UUID,MOUNTPOINT | while read -r DEV FSTYPE LABEL UUID MOUNT; do
    if [ -n "$FSTYPE" ] && [ "$FSTYPE" != "swap" ] && [ -z "$MOUNT" ]; then
        MOUNT_NAME="${LABEL:-$UUID}"
        if [ -z "$MOUNT_NAME" ]; then
            continue
        fi
        MOUNT_DIR="/media/$MOUNT_NAME"
        mkdir -p "$MOUNT_DIR" > /dev/null
        if [ -n "$UUID" ]; then
            FSTAB_IDENT="UUID=$UUID"
        else
            FSTAB_IDENT="$DEV"
        fi
        if ! grep -q "$MOUNT_DIR" /etc/fstab && ! grep -q "$FSTAB_IDENT" /etc/fstab; then
            echo "$FSTAB_IDENT  $MOUNT_DIR  $FSTYPE  defaults,nofail,x-systemd.device-timeout=5  0  2" >> /etc/fstab
        fi
        mount "$MOUNT_DIR" > /dev/null 2>&1 || mount "$DEV" "$MOUNT_DIR" > /dev/null 2>&1
    fi
done
systemctl daemon-reload > /dev/null 2>&1
mount -a > /dev/null 2>&1
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Montage des disques : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Exécution des installateurs : PENDING" >> "$LOG_FILE"
MODULES=("Apollon" "Athena" "Cerbere" "Hades" "Hermes" "Promethee")
for module in "${MODULES[@]}"; do
    SCRIPT_PATH="/etc/AubeZero/${module}/install.sh"
    if [ -f "$SCRIPT_PATH" ]; then
        echo "$(date +'%Y%m%d%H:%M')-${Programme}-Lancement de ${module} : PENDING" >> "$LOG_FILE"
        chmod +x "$SCRIPT_PATH"
        if bash "$SCRIPT_PATH" > /dev/null 2>&1; then
            echo "$(date +'%Y%m%d%H:%M')-${Programme}-Lancement de ${module} : SUCCESS" >> "$LOG_FILE"
        else
            echo "$(date +'%Y%m%d%H:%M')-${Programme}-Lancement de ${module} : FAILED" >> "$LOG_FILE"
        fi
    else
        echo "$(date +'%Y%m%d%H:%M')-${Programme}-Script ${module} introuvable : SKIPPED" >> "$LOG_FILE"
    fi
done
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Exécution des installateurs : SUCCESS" >> "$LOG_FILE"#!/bin/bash
