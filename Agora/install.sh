#!/bin/sh
# Agora - Install
# @Author : ROYJohan
# @Version : 1.0.0
# @Date : 2026-09-21
# @Desc : Script principal d'orchestration, de déploiement et d'initialisation du système AubeZero

# Stop en cas d'erreur ou de variable non définie
set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "Droits insuffisants : exécuter ce script en tant que root." >&2
    exit 1
fi

# === 2. Chargement des variables & Cerbère ===
BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CREDENTIALS_FILE="$CERBERE_DIR/credentials.env"

# Création du dossier Cerbere si absent
mkdir -p "$CERBERE_DIR"

# Chargement de credentials.env s'il existe
if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# Valeurs par défaut codées en dur (conformité cahier des charges)
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
PORT_LAMP="${PORT_LAMP:-81}"
PATH_LAMP="${PATH_LAMP:-/var/www/html}"
PATH_PMTILES="${PATH_PMTILES:-/var/www/html/europe.pmtiles}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/ROYJohan08/AubeZero/refs/heads/main}"

# === 3. Initialisation de Mnémosyne (Journalisation) ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-AGORA-INSTALL.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Lancement de l'installation Agora AubeZero"

# Redirection de stdout globale vers le log Mnémosyne
exec 1>>"$LOG_FILE"

# === 4. Arborescence des sous-modules ===
log "PENDING" "Création des répertoires de sous-modules"
MODULES="Cerbere Argos Apollon Athena Hades Hermes Promethee Zeus Agora"
mkdir -p "$BASE_DIR/Agora"
for mod in $MODULES; do
    mkdir -p "$BASE_DIR/$mod"
done
log "+" "Création des répertoires terminée"

# === 5. Téléchargement / Synchronisation des sous-modules (Hybride) ===
log "PENDING" "Synchronisation des installateurs de modules"
for mod in $MODULES; do
    TARGET="$BASE_DIR/$mod/install.sh"
    URL="$BASE_URL/$mod/install.sh"
    
    # Téléchargement silencieux si réseau accessible
    if curl --fail --silent --show-error -o "$TARGET" "$URL" 2>/dev/null; then
        chmod 700 "$TARGET"
        log "+" "Mise à jour distante réussie pour $mod"
    else
        if [ -f "$TARGET" ]; then
            log "⚠️" "Réseau indisponible. Utilisation de la version locale de $mod"
        else
            log "[-]" "Impossible de récupérer $mod et aucune copie locale disponible"
        fi
    fi
done

# === 6. Mise à jour du système & Dépendances ===
log "PENDING" "Mise à jour du système et installation des paquetages requis"
export DEBIAN_FRONTEND=noninteractive

if apt-get update -qq 2>/dev/null; then
    apt-get upgrade -y -qq
    apt-get full-upgrade -y -qq
    apt-get autoremove -y --purge -qq
    apt-get autoclean -y -qq
    
    apt-get install -y -qq ca-certificates curl gnupg software-properties-common
    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" \
        | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
    chmod a+r /etc/apt/keyrings/docker.gpg 2>/dev/null || true
    
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
    
    apt-get update -qq 2>/dev/null || true
    apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
        webp imagemagick ffmpeg unzip p7zip-full unrar \
        git net-tools iperf samba \
        python3 python3-pip python3-dev python3-psutil lm-sensors hddtemp || true
    log "+" "Mise à jour et paquets installés avec succès"
else
    log "⚠️" "Mode Hors-ligne : étape de mise à jour des paquets ignorée"
fi

# === 7. Configuration des alias ===
log "PENDING" "Configuration des alias utilisateur"
BASHRC_URL="$BASE_URL/Agora/.bashrc"
BASHRC_LOCAL="$BASE_DIR/Agora/.bashrc"
if curl --fail --silent --show-error -o "$BASHRC_LOCAL" "$BASHRC_URL" 2>/dev/null; then
    cp -f "$BASHRC_LOCAL" /root/.bashrc
    for user_dir in /home/*; do
        [ -d "$user_dir" ] || continue
        user=$(basename "$user_dir")
        cp -f "$BASHRC_LOCAL" "$user_dir/.bashrc"
        chown "$user:$user" "$user_dir/.bashrc"
    done
    log "+" "Alias mis à jour"
else
    log "⚠️" "Fichier .bashrc distant indisponible, conservation du fichier local"
fi

# === 8. Désactivation de la veille système ===
log "PENDING" "Désactivation des modes de mise en veille"
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true
mkdir -p /etc/systemd/sleep.conf.d
cat <<EOF > /etc/systemd/sleep.conf.d/nosuspend.conf
[Sleep]
AllowSuspend=no
AllowHibernation=no
AllowSuspendThenHibernate=no
AllowHybridSleep=no
EOF
log "+" "Veille système désactivée"

# === 9. Montage automatique des disques ===
log "PENDING" "Montage automatique des volumes de stockage"
lsblk -pbno NAME,FSTYPE,LABEL,UUID,MOUNTPOINT | while read -r DEV FSTYPE LABEL UUID MOUNT; do
    [ -n "$FSTYPE" ] && [ "$FSTYPE" != "swap" ] && [ -z "$MOUNT" ] || continue
    MOUNT_NAME="${LABEL:-$UUID}"
    [ -n "$MOUNT_NAME" ] || continue
    MOUNT_DIR="/media/$MOUNT_NAME"
    mkdir -p "$MOUNT_DIR"
    IDENTIFIER="${UUID:+UUID=$UUID}"
    IDENTIFIER="${IDENTIFIER:-$DEV}"
    if ! grep -q "$MOUNT_DIR" /etc/fstab && ! grep -q "$IDENTIFIER" /etc/fstab; then
        echo "$IDENTIFIER  $MOUNT_DIR  $FSTYPE  defaults,nofail,x-systemd.device-timeout=5  0  2" >> /etc/fstab
    fi
    mount "$MOUNT_DIR" >/dev/null 2>&1 || mount "$DEV" "$MOUNT_DIR" >/dev/null 2>&1
done
systemctl daemon-reload >/dev/null 2>&1 || true
mount -a >/dev/null 2>&1 || true
log "+" "Montage des disques effectué"

# === 10. Exécution séquentielle des sous-modules ===
log "PENDING" "Lancement des scripts d'installation des sous-modules"
for mod in $MODULES; do
    [ "$mod" = "Agora" ] && continue
    SCRIPT="$BASE_DIR/$mod/install.sh"
    if [ -f "$SCRIPT" ]; then
        log "👉" "Exécution de $mod/install.sh"
        if sh "$SCRIPT" >> "$LOG_FILE" 2>&1; then
            log "+" "Module $mod installé avec succès"
        else
            log "[-]" "Échec d'exécution du module $mod"
            if [ "$mod" = "Cerbere" ]; then
                echo "Erreur critique : L'installation de Cerbere a échoué." >&2
                exit 1
            fi
        fi
    else
        log "⚠️" "Script $mod/install.sh introuvable"
    fi
done

# Rechargement de credentials.env au cas où Cerbere l'aurait généré durant son installation
if [ -f "$CREDENTIALS_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CREDENTIALS_FILE"
fi

# === 11. Création du binaire /usr/local/bin/lamp ===
log "PENDING" "Création de la commande /usr/local/bin/lamp"
cat <<'EOF' > /usr/local/bin/lamp
#!/bin/sh

BASE_DIR="/etc/AubeZero"
CREDENTIALS_FILE="$BASE_DIR/Cerbere/credentials.env"

if [ -f "$CREDENTIALS_FILE" ]; then
    . "$CREDENTIALS_FILE"
fi

PORT_LAMP="${PORT_LAMP:-81}"
PATH_LAMP="${PATH_LAMP:-/var/www/html}"
PATH_PMTILES="${PATH_PMTILES:-/var/www/html/europe.pmtiles}"

create_lamp_container() {
    echo "Instanciation du conteneur LAMP (Port externe : $PORT_LAMP)..."
    mkdir -p "$PATH_LAMP"
    touch "$PATH_PMTILES" 2>/dev/null || true
    docker run -d \
        --name lamp \
        --restart=unless-stopped \
        -e TZ=CET \
        -v "$PATH_LAMP:/var/www/html" \
        -v "$PATH_PMTILES:/var/www/html/europe.pmtiles:ro" \
        -v /media/:/media \
        -p "$PORT_LAMP:80" \
        -p 3306:3306 \
        php:8.2-apache
}

case "${1:-}" in
    start)
        if docker ps -a --format '{{.Names}}' | grep -q '^lamp$'; then
            docker start lamp
        else
            create_lamp_container
        fi
        ;;
    stop)
        docker stop lamp
        ;;
    restart)
        docker restart lamp
        ;;
    update)
        docker pull php:8.2-apache 2>/dev/null || true
        docker rm -f lamp >/dev/null 2>&1 || true
        create_lamp_container
        ;;
    *)
        echo "Usage: lamp {start|stop|restart|update}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/lamp
log "+" "Commande /usr/local/bin/lamp configurée"

# === 12. Démarrage & Initialisation du conteneur LAMP ===
log "PENDING" "Initialisation du conteneur LAMP"
/usr/local/bin/lamp update >> "$LOG_FILE" 2>&1 || true
log "+" "Conteneur LAMP opérationnel"

log "+" "Installation du système AubeZero/Agora terminée avec succès."
