#!/bin/bash

# 1. Vérification des privilèges Root
if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root."
    exit 1
fi

# 2. Configuration des chemins et des logs
LOG_DIR="/etc/AubeZero/Log"
OLD_DIR="/etc/AubeZero/Old"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Agora-update"

# Création des répertoires nécessaires s'ils n'existent pas
mkdir -p "$LOG_DIR" "$OLD_DIR"

# Début du log
echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] START" >> "$LOG_FILE"

# 3. Mises à jour système globales
echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Début de la mise à jour système..." >> "$LOG_FILE"
apt-get update -y > /dev/null 2>&1
apt-get full-upgrade -y > /dev/null 2>&1
apt-get autoremove -y > /dev/null 2>&1
apt-get autoclean -y > /dev/null 2>&1

# 4. Mises à jour ciblées des services
echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Mise à jour des paquets spécifiques..." >> "$LOG_FILE"
apt-get update -y > /dev/null 2>&1
apt-get upgrade docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y > /dev/null 2>&1
apt-get install --only-upgrade git-all -y > /dev/null 2>&1
apt-get install --only-upgrade net-tools iperf -y > /dev/null 2>&1
apt-get install --only-upgrade smartmontools -y > /dev/null 2>&1
apt-get install --only-upgrade samba -y > /dev/null 2>&1
apt-get install --only-upgrade cron -y > /dev/null 2>&1
apt-get install --only-upgrade python3 python3-pip -y > /dev/null 2>&1

# 5. Configuration Samba
echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Mise à jour de la configuration Samba..." >> "$LOG_FILE"
wget -q -N https://github.com/ROYJohan08/RJI-Domonas/raw/refs/heads/main/sources/smb.conf -O /etc/samba/smb.conf
service smbd start > /dev/null 2>&1

# 6. Gestion et mise à jour des .bashrc
TEMP_BASHRC="/tmp/.bashrc"
wget -q -N https://github.com/ROYJohan08/RJI-Domonas/raw/refs/heads/main/sources/.bashrc -O "$TEMP_BASHRC"

if [ -f "$TEMP_BASHRC" ]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Mise à jour des fichiers .bashrc..." >> "$LOG_FILE"
    rm -rf /home/*/.bashrc.* /root/.bashrc.*
    
    # Mise à jour pour chaque utilisateur du /home
    for user_home in /home/*; do
        if [ -d "$user_home" ]; then
            username=$(basename "$user_home")
            
            if [ -f "$user_home/.bashrc" ]; then
                mv -f "$user_home/.bashrc" "$OLD_DIR/${username}.bashrc"
            fi
            
            cp -f "$TEMP_BASHRC" "$user_home/.bashrc"
            chown "$username:$username" "$user_home/.bashrc"
            chmod 644 "$user_home/.bashrc"
        fi
    done

    # Mise à jour pour root
    if [ -f /root/.bashrc ]; then
        cp -f /root/.bashrc "$OLD_DIR/root.bashrc.bak"
    fi
    mv -f "$TEMP_BASHRC" /root/.bashrc
    chmod 644 /root/.bashrc
    
    # Rechargement pour la session active du script root
    source /root/.bashrc
else
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] ERREUR : Échec du téléchargement du .bashrc" >> "$LOG_FILE"
fi

# 7. Mise à jour de la Crontab root
echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Mise à jour de la crontab..." >> "$LOG_FILE"
TEMP_CRON="/tmp/mycron"
wget -q -N https://github.com/ROYJohan08/RJI-Domonas/raw/refs/heads/main/sources/mycron -O "$TEMP_CRON"

if [ -f "$TEMP_CRON" ]; then
    crontab "$TEMP_CRON"
    rm -f "$TEMP_CRON"
else
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] ERREUR : Échec du téléchargement de la crontab" >> "$LOG_FILE"
fi

# 8. Exécution des scripts de mise à jour des modules sous /etc/AubeZero/ (en toute fin)
echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Exécution des scripts update.sh des modules..." >> "$LOG_FILE"
for module_script in /etc/AubeZero/*/update.sh; do
    if [ -f "$module_script" ] && [ -x "$module_script" ]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Lancement de : $module_script" >> "$LOG_FILE"
        "$module_script" >> "$LOG_FILE" 2>&1
    elif [ -f "$module_script" ]; then
        chmod +x "$module_script"
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] Lancement de (après chmod) : $module_script" >> "$LOG_FILE"
        "$module_script" >> "$LOG_FILE" 2>&1
    fi
done

# Fin du log
echo "[$(date "+%Y-%m-%d %H:%M:%S")] [$Programme] END" >> "$LOG_FILE"