#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root."
    exit 1
fi

LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Agora-Install"
mkdir -p "$LOG_DIR"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Création des dossiers : PENDING" >> "$LOG_FILE"
mkdir -p /etc/AubeZero/{Agora,Apollon,Athena,Cerbere,Hades,Hermes,Promethee}
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Création des dossiers : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des installateurs : PENDING" >> "$LOG_FILE"
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main"
wget -q -N "$BASE_URL/Apollon/install.sh" -O /etc/AubeZero/Apollon/install.sh
wget -q -N "$BASE_URL/Athena/install.sh" -O /etc/AubeZero/Athena/install.sh
wget -q -N "$BASE_URL/Cerbere/install.sh" -O /etc/AubeZero/Cerbere/install.sh
wget -q -N "$BASE_URL/Hades/install.sh" -O /etc/AubeZero/Hades/install.sh
wget -q -N "$BASE_URL/Hermes/install.sh" -O /etc/AubeZero/Hermes/install.sh
wget -q -N "$BASE_URL/Promethee/install.sh" -O /etc/AubeZero/Promethee/install.sh
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des installateurs : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Mise a jours du système : PENDING" >> "$LOG_FILE"
apt-get update -y -qq
apt-get upgrade -y -qq
apt-get full-upgrade -y -qq
apt-get autoclean -y -qq
apt-get autoremove -y --purge -qq
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Mise a jours du système : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation des programmes : PENDING" >> "$LOG_FILE"
apt-get install -y -qq ca-certificates curl gnupg > /dev/null
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y -qq > /dev/null
apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null
apt-get install git-all net-tools iperf samba -y > /dev/null
ubuntu-drivers list --gpgpu > /dev/null
add-apt-repository ppa:deadsnakes/ppa -y > /dev/null
apt-get update -y > /dev/null
apt-get install python3 python3-pip -y > /dev/null
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Installation des programmes : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Modification des alias : PENDING" >> "$LOG_FILE"
wget -q -N "$BASE_URL/Agora/.bashrc" -O /etc/AubeZero/Agora/.bashrc
cp -f /etc/AubeZero/Agora/.bashrc /root/.bashrc
for user_dir in /home/*; do
  if [ -d "$user_dir" ]; then
    username=$(basename "$user_dir")
    cp -f /etc/AubeZero/Agora/.bashrc "$user_dir/.bashrc"
    chown "$username:$username" "$user_dir/.bashrc"
  fi
done
source ~/.bashrc
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Modification des alias : SUCCESS" >> "$LOG_FILE"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Désactivation de la veille : PENDING" >> "$LOG_FILE"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
mkdir -p /etc/systemd/sleep.conf.d
cat <<EOF > /etc/systemd/sleep.conf.d/nosuspend.conf
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF
if [ -f /etc/gdm3/greeter.dconf-defaults ]; then
  echo 'sleep-inactive-ac-type="blank"' >> /etc/gdm3/greeter.dconf-defaults
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
            # Options adaptées : noatime pour limiter l'usure, nofail pour ne pas bloquer le boot si absent
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
    if bash "$SCRIPT_PATH" >> "$LOG_FILE" 2>&1; then
      echo "$(date +'%Y%m%d%H:%M')-${Programme}-Lancement de ${module} : SUCCESS" >> "$LOG_FILE"
    else
      echo "$(date +'%Y%m%d%H:%M')-${Programme}-Lancement de ${module} : FAILED" >> "$LOG_FILE"
    fi
  else
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-Script ${module} introuvable : SKIPPED" >> "$LOG_FILE"
  fi
done
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Exécution des installateurs : SUCCESS" >> "$LOG_FILE"
