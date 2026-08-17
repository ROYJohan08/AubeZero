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
Programme="Cerbere-update"

# Création des répertoires nécessaires s'ils n'existent pas
mkdir -p "$LOG_DIR" "$OLD_DIR"

# 3. Télécharger le fichier par défaut s'il n'existe pas du tout
if [ ! -f /etc/AubeZero/Cerbere/credentials.sh ]; then
    mkdir -p /etc/AubeZero/Cerbere
    wget -qO /etc/AubeZero/Cerbere/credentials.sh https://github.com/ROYJohan08/RJI-Domonas/raw/refs/heads/main/sources/credentials.sh
fi

# 4. Restaurer/Mettre à jour depuis la sauvegarde uniquement si elle est plus récente
if [ -f /media/Runable/Docker/credentials.sh ] && [ /media/Runable/Docker/credentials.sh -nt /etc/AubeZero/Cerbere/credentials.sh ]; then
    cp -f /media/Runable/Docker/credentials.sh /etc/AubeZero/Cerbere/credentials.sh
    echo "Mise à jour/Restauration credentials depuis sauvegarde : SUCCESS" >> "$LOG_FILE"
fi