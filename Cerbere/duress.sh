#!/bin/bash
# cerbere-duress.sh
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 15/09/2026 13:37
# @Desc : Installation et configuration du système de Duress Code pour Cerbere

exec 1>/dev/null
set -euo pipefail

# === LOG SYSTEM === #
Programme="Cerbere-Duress"
DEFAULT_LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_DIR="$DEFAULT_LOG_DIR"

log() {
    mkdir -p "$LOG_DIR" > /dev/null
    echo "$(date +'%Y%m%d%H%M')-${Programme}-$1" >> "${LOG_DIR}/$(date +%Y-%m).log"
}

log "[👉] Début du programme"

# === Vérification des droits === #
if [[ "$EUID" -ne 0 ]]; then
    log "[-] Droits insuffisants : exécution non-root"
    exit 1
fi
log "[+] Droits root confirmés"

# === Chargement des credentials === #
CRED_FILE="/etc/AubeZero/Cerbere/Credentials.env"
if [[ -f "$CRED_FILE" ]]; then
    set -a
    source "$CRED_FILE"
    set +a
    log "[~] credentials.env chargé"
else
    log "[-] credentials.env introuvable : arrêt"
    exit 1
fi

# === Mise à jour du LOG_DIR depuis credentials.env === #
if [[ -n "${PATH_MNEMOSYNE:-}" ]]; then
    LOG_DIR="$PATH_MNEMOSYNE"
    log "[+] LOG_DIR défini depuis credentials.env : $LOG_DIR"
else
    LOG_DIR="$DEFAULT_LOG_DIR"
    log "[~] PATH_MNEMOSYNE absent : fallback vers $LOG_DIR"
fi

# === Récupération du code duress === #
DURESS_PASSWORD="${PASSWORD_DURESS:-M3m0ry4*}"
if [[ -z "$DURESS_PASSWORD" ]]; then
    DURESS_PASSWORD="duress*"
fi
log "[+] DuressCode défini"

# === Récupération de l’utilisateur duress === #
DURESS_USER="${USERNAME_DURESS:-duress}"
log "[+] Utilisateur duress : $DURESS_USER"
# === Préparation des chemins === #
CERBERE_DIR="/etc/AubeZero/Cerbere"
mkdir -p "$CERBERE_DIR"
DURESS_SCRIPT="$CERBERE_DIR/duress_check.sh"
PAM_WRAPPER="$CERBERE_DIR/duress_pam.sh"
BASE_URL="https://raw.githubusercontent.com/ROYJohan08/AubeZero/main/Cerbere/duress_check.sh"
# === Vérification version locale vs GitHub === #
log "[~] Vérification du script duress_check.sh"
TMP_GITHUB="/tmp/duress_check_new.sh"

if curl --fail --silent --show-error -o "$TMP_GITHUB" "$BASE_URL"; then
    log "[+] Version GitHub récupérée"
else
    log "[-] Impossible de récupérer la version GitHub"
fi

# Installation ou mise à jour
if [[ ! -f "$DURESS_SCRIPT" ]]; then
    cp "$TMP_GITHUB" "$DURESS_SCRIPT"
    chown root:root "$DURESS_SCRIPT"
    chmod 700 "$DURESS_SCRIPT"
    log "[+] duress_check.sh installé (nouveau)"
else
    LOCAL_HASH=$(sha256sum "$DURESS_SCRIPT" | awk '{print $1}')
    REMOTE_HASH=$(sha256sum "$TMP_GITHUB" | awk '{print $1}')
    if [[ "$LOCAL_HASH" != "$REMOTE_HASH" ]]; then
        cp "$TMP_GITHUB" "$DURESS_SCRIPT"
        chown root:root "$DURESS_SCRIPT"
        chmod 700 "$DURESS_SCRIPT"
        log "[+] duress_check.sh mis à jour (version plus récente)"
    else
        log "[~] duress_check.sh déjà à jour"
    fi
fi
rm -f "$TMP_GITHUB"

# === Création de l’utilisateur duress === #
log "[~] Vérification de l’utilisateur duress"
if ! id "$DURESS_USER" &>/dev/null; then
    useradd -r -s /bin/false "$DURESS_USER" >/dev/null
    log "[+] Utilisateur duress créé"
else
    log "[~] Utilisateur duress déjà existant"
fi
echo "$DURESS_USER:$DURESS_PASSWORD" | chpasswd >/dev/null
log "[+] Mot de passe duress configuré"

# === Création du wrapper PAM === #
log "[~] Installation du wrapper PAM"
cat << EOF > "$PAM_WRAPPER"
#!/bin/bash
if [ "\$PAM_USER" = "$DURESS_USER" ]; then
    $DURESS_SCRIPT &
    exit 1
fi
exit 0
EOF
chown root:root "$PAM_WRAPPER"
chmod 700 "$PAM_WRAPPER"
log "[+] Wrapper PAM installé"

# === Injection dans PAM === #
PAM_FILE="/etc/pam.d/common-auth"
PAM_RULE="auth [success=end default=ignore] pam_exec.so quiet $PAM_WRAPPER"
log "[~] Vérification de la règle PAM"
if ! grep -q "$PAM_WRAPPER" "$PAM_FILE"; then
    cp "$PAM_FILE" "${PAM_FILE}.bak_cerbere"
    sed -i "1i $PAM_RULE" "$PAM_FILE"
    log "[+] Règle PAM ajoutée"
else
    log "[~] Règle PAM déjà présente"
fi

# === FIN === #
log "[✓] Installation et configuration du duress code terminée"
