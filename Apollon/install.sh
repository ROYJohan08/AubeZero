#!/bin/bash

# === Vérification des droits administrateurs === #
if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root." >&2
    exit 1
fi

# === Stop en cas d'erreurs === #
set -euo pipefail

# === Définition des variables === #
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Apollon-Install"
RSYNC_HOST="rsync://download.kiwix.org/zim/builds"
ZIM_FILES=(
    "devdocs_en_apache-http-server_2026-04.zim"
    "devdocs_en_bash_2026-04.zim"
    "devdocs_en_c_2026-04.zim"
    "devdocs_en_cpp_2026-04.zim"
    "devdocs_en_css_2026-04.zim"
    "devdocs_en_docker_2026-04.zim"
    "devdocs_en_git_2026-04.zim"
    "devdocs_en_html_2026-04.zim"
    "devdocs_en_javascript_2026-04.zim"
    "devdocs_en_jquery_2026-04.zim"
    "devdocs_en_man_2026-04.zim"
    "devdocs_en_mariadb_2026-04.zim"
    "devdocs_en_markdown_2026-04.zim"
    "devdocs_en_postgresql_2026-05.zim"
    "devdocs_en_python_2026-05.zim"
    "devdocs_en_sqlite_2026-04.zim"
    "devdocs_en_wordpress_2026-04.zim"
    "doc.ubuntu-fr.org_fr_all_2026-05.zim"
    "education-et-numerique_fr_all_2021-07.zim"
    "phet_fr_all_2026-02.zim"
    "pokepedia_fr_all_maxi_2026-04.zim"
    "psiram_fr_all_maxi_2026-02.zim"
    "scratch-wiki_fr_all_maxi_2021-02.zim"
    "solar.lowtechmagazine.com_mul_all_2025-01.zim"
    "wikipedia_fr_all_nopic_2026-02.zim"
    "wikipedia_fr_chemistry_maxi_2026-04.zim"
    "wikipedia_fr_computer_maxi_2026-04.zim"
    "wikipedia_fr_geography_maxi_2026-04.zim"
    "wikipedia_fr_history_maxi_2026-04.zim"
    "wikipedia_fr_medicine_maxi_2026-04.zim"
    "wikipedia_fr_physics_maxi_2026-04.zim"
    "wikiquote_fr_all_maxi_2026-04.zim"
    "wikivoyage_fr_all_maxi_2026-03.zim"
    "wiktionary_fr_all_nopic_2026-05.zim"
    "youscribe_fr_college_2024-05.zim"
    "youscribe_fr_lycee_2024-05.zim"
    "youscribe_fr_primaire_2024-05.zim"
)

# === Création du dossier === #
mkdir -p "$PathDkKiwix"

# === Téléchargement des ZIM === #
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des .zim : PENDING" >> "$LOG_FILE"
for file in "${ZIM_FILES[@]}"; do
    rsync -avP "$RSYNC_HOST/$file" "$PathDkKiwix/" || echo "$(date +'%Y%m%d%H:%M')-${Programme}-Echec de téléchargement de : $file" >> "$LOG_FILE"
done
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des .zim : SUCCESS" >> "$LOG_FILE"

# === Démarage du docker kiwix === #
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Démarrage du docker kiwix : PENDING" >> "$LOG_FILE"
sudo docker rm -rf kiwix
sudo docker pull ghcr.io/kiwix/kiwix-serve:latest
sudo docker run -d \
  --name kiwix \
	--restart=unless-stopped \
	-p "$PortKiwix:8080" \
	-v "$PathDkKiwix:/data" \
	ghcr.io/kiwix/kiwix-serve:latest \
	/data/*.zim
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Démarrage du docker kiwix : SUCCESS" >> "$LOG_FILE"
