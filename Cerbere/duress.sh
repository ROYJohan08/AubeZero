#!/bin/sh
# Cerbere - Duress
# @Author : ROYJohan
# @Version : 3.0.0
# @Date : 2026-09-21
# @Desc : Installation et configuration du système de Duress Code pour Cerbere

# Stop en cas d'erreur ou de variable non définie
set -eu

# === 1. Vérification des droits root ===
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Droits insuffisants : exécution non-root" >&2
    exit 1
fi

# === 2. Répertoires et configuration Cerbere ===
BASE_DIR="/etc/AubeZero"
CERBERE_DIR="$BASE_DIR/Cerbere"
CRED_FILE="$CERBERE_DIR/credentials.env"

mkdir -p "$CERBERE_DIR"

# Chargement dynamique du fichier credentials.env s'il existe
if [ -f "$CRED_FILE" ]; then
    # shellcheck disable=SC1090
    . "$CRED_FILE"
fi

# Valeurs par défaut codées en dur
PATH_MNEMOSYNE="${PATH_MNEMOSYNE:-/etc/AubeZero/Mnemosyne}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/ROYJohan08/AubeZero/main}/Cerbere/duress_check.sh"
DURESS_PASSWORD="${PASSWORD_DURESS:-M3m0ry4*}"
DURESS_USER="${USERNAME_DURESS:-duress}"

# === 3. Initialisation de la journalisation Mnémosyne ===
mkdir -p "$PATH_MNEMOSYNE"
DATE_LOG=$(date +'%Y%m%d')
LOG_FILE="$PATH_MNEMOSYNE/${DATE_LOG}-CERBERE-DURESS.log"

log() {
    _tag="$1"
    _msg="$2"
    echo "[$_tag] - $(date +'%Y-%m-%d %H:%M:%S') - $_msg" >> "$LOG_FILE"
}

log "👉" "Début du programme Cerbere-Duress"

# Redirection de stdout globale vers le log Mnémosyne (Quiet mode)
exec 1>>"$LOG_FILE"

# === 4. Récupération & Mise à jour de duress_check.sh (Hybride) ===
DURESS_SCRIPT="$CERBERE_DIR/duress_check.sh"
PAM_WRAPPER="$CERBERE_DIR/duress_pam.sh"
TMP_GITHUB="/tmp/duress_check_new.sh"

log "~" "Vérification de la version de duress_check.sh"

if curl --fail --silent --show-error -o "$TMP_GITHUB" "$BASE_URL" 2>/dev/null; then
    log "+" "Version distante récupérée depuis le dépôt"
    
    if [ ! -f "$DURESS_SCRIPT" ]; then
        cp "$TMP_GITHUB" "$DURESS_SCRIPT"
        chown root:root "$DURESS_SCRIPT" 2>/dev/null || true
        chmod 700 "$DURESS_SCRIPT"
        log "+" "duress_check.sh installé (nouvelle installation)"
    else
        LOCAL_HASH=$(sha256sum "$DURESS_SCRIPT" | awk '{print $1}')
        REMOTE_HASH=$(sha256sum "$TMP_GITHUB" | awk '{print $1}')
        if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
            cp "$TMP_GITHUB" "$DURESS_SCRIPT"
            chown root:root "$DURESS_SCRIPT" 2>/dev/null || true
            chmod 700 "$DURESS_SCRIPT"
            log "+" "duress_check.sh mis à jour (différence SHA256)"
        else
            log "=" "duress_check.sh déjà à jour"
        fi
    fi
    rm -f "$TMP_GITHUB"
else
    if [ -f "$DURESS_SCRIPT" ]; then
        log "~" "Réseau indisponible : utilisation de la version locale de duress_check.sh"
    else
        log "[-]" "Impossible de récupérer duress_check.sh et aucun fichier local disponible"
        echo "[-] Erreur critique : duress_check.sh introuvable." >&2
        exit 1
    fi
fi

# === 5. Création de l'utilisateur duress ===
log "~" "Vérification de l'existence de l'utilisateur $DURESS_USER"
if ! id "$DURESS_USER" >/dev/null 2>&1; then
    useradd -r -s /bin/false "$DURESS_USER" >/dev/null 2>&1 || true
    log "+" "Utilisateur $DURESS_USER créé"
else
    log "=" "Utilisateur $DURESS_USER déjà présent"
fi

echo "$DURESS_USER:$DURESS_PASSWORD" | chpasswd >/dev/null 2>&1 || true
log "+" "Mot de passe duress configuré"

# === 6. Création du wrapper PAM POSIX ===
log "~" "Génération du wrapper PAM $PAM_WRAPPER"
cat << EOF > "$PAM_WRAPPER"
#!/bin/sh
if [ "\${PAM_USER:-}" = "$DURESS_USER" ]; then
    $DURESS_SCRIPT &
    exit 1
fi
exit 0
EOF

chown root:root "$PAM_WRAPPER" 2>/dev/null || true
chmod 700 "$PAM_WRAPPER"
log "+" "Wrapper PAM installé"

# === 7. Configuration du module PAM ===
PAM_FILE="/etc/pam.d/common-auth"
PAM_RULE="auth [success=end default=ignore] pam_exec.so quiet $PAM_WRAPPER"

log "~" "Configuration de la règle dans $PAM_FILE"
if [ -f "$PAM_FILE" ]; then
    if ! grep -q "$PAM_WRAPPER" "$PAM_FILE"; then
        cp "$PAM_FILE" "${PAM_FILE}.bak_cerbere"
        # Insertion sécurisée de la règle en début de fichier
        sed -i "1i $PAM_RULE" "$PAM_FILE"
        log "+" "Règle PAM ajoutée à $PAM_FILE"
    else
        log "=" "Règle PAM déjà présente dans $PAM_FILE"
    fi
else
    log "[-]" "Fichier de configuration PAM $PAM_FILE introuvable"
fi

log "✓" "Installation et configuration de Cerbere-Duress terminées avec succès"
