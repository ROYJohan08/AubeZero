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
BASE_DIR="/media/Docs01/Logiciels/StandaloneInstaller"
WGET_FLAGS="-N -c -q --show-progress"
USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64)"

# === Création du dossier === #
mkdir -p "$LOG_DIR"
mkdir -p "$PathDkKiwix"
mkdir -p "$BASE_DIR"/{Firefox,Chrome,VLC,Jellyfin,HomeAssistant,Rufus,ImageGlass,PuTTY,FileZilla,NotepadPlusPlus,AnyDesk,LibreOffice,WinRAR,ISOs}
mkdir -p "$BASE_DIR/Firefox/"{Windows,Mac,Linux,Android}
mkdir -p "$BASE_DIR/Chrome/"{Windows,Mac,Linux}
mkdir -p "$BASE_DIR/VLC/"{Windows,Mac,Android}
mkdir -p "$BASE_DIR/Jellyfin/Android"
mkdir -p "$BASE_DIR/HomeAssistant/Android"
mkdir -p "$BASE_DIR/AnyDesk/"{Windows,Mac,Linux,Android}
mkdir -p "$BASE_DIR/LibreOffice/"{Windows,Mac,Linux}
mkdir -p "$BASE_DIR/ISOs/"{Ubuntu,Windows}


# === Téléchargement des ZIM === #
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des .zim : PENDING" >> "$LOG_FILE"
for file in "${ZIM_FILES[@]}"; do
    rsync -avP "$RSYNC_HOST/$file" "$PathDkKiwix/" || echo "$(date +'%Y%m%d%H:%M')-${Programme}-Echec de téléchargement de : $file" >> "$LOG_FILE"
done
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des .zim : SUCCESS" >> "$LOG_FILE"

# === Téléchargement des installateurs standalone === #
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des standalone installers : PENDING" >> "$LOG_FILE"
wget $WGET_FLAGS -O "$BASE_DIR/Firefox/Windows/Firefox_Setup_Win64.exe" "https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=fr"
wget $WGET_FLAGS -O "$BASE_DIR/Firefox/Mac/Firefox.dmg" "https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=fr"
wget $WGET_FLAGS -O "$BASE_DIR/Firefox/Linux/firefox.tar.bz2" "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=fr"
wget $WGET_FLAGS -O "$BASE_DIR/Firefox/Android/Firefox.apk" "https://download.mozilla.org/?product=fennec-latest&os=android&lang=multi"
wget $WGET_FLAGS -O "$BASE_DIR/Chrome/Windows/ChromeStandaloneSetup64.exe" "https://dl.google.com/chrome/install/standalone/current/chrome_installer.exe"
wget $WGET_FLAGS -O "$BASE_DIR/Chrome/Mac/googlechrome.dmg" "https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg"
wget $WGET_FLAGS -O "$BASE_DIR/Chrome/Linux/google-chrome-stable_current_amd64.deb" "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
wget $WGET_FLAGS -O "$BASE_DIR/VLC/Windows/vlc-win64.exe" "https://get.videolan.org/vlc/last/win64/vlc-3.0.21-win64.exe"
wget $WGET_FLAGS -O "$BASE_DIR/VLC/Mac/vlc.dmg" "https://get.videolan.org/vlc/last/macosx/vlc-3.0.21-intel64.dmg"
wget $WGET_FLAGS -O "$BASE_DIR/VLC/Android/VLC-Android.apk" "https://get.videolan.org/vlc-android/3.5.4/VLC-Android-3.5.4-arm64-v8a.apk"
wget $WGET_FLAGS -O "$BASE_DIR/Jellyfin/Android/jellyfin-android.apk" "https://github.com/jellyfin/jellyfin-android/releases/latest/download/jellyfin-android-v0.17.8-release.apk"
wget $WGET_FLAGS -O "$BASE_DIR/HomeAssistant/Android/home-assistant-android.apk" "https://github.com/home-assistant/android/releases/latest/download/app-minimal-release.apk"
wget $WGET_FLAGS -O "$BASE_DIR/Rufus/rufus.exe" "https://github.com/pbatard/rufus/releases/download/v4.6/rufus-4.6.exe"
wget $WGET_FLAGS -O "$BASE_DIR/ImageGlass/ImageGlass_Installer.exe" "https://github.com/d2phap/ImageGlass/releases/download/v9.3.0.1019/ImageGlass_9.3.0.1019_x64.exe"
wget $WGET_FLAGS -O "$BASE_DIR/PuTTY/putty-64bit-installer.msi" "https://the.earth.li/~sgtatham/putty/latest/w64/putty-64bit-installer.msi"
wget $WGET_FLAGS -O "$BASE_DIR/FileZilla/FileZilla_Win64_setup.exe" --user-agent="$USER_AGENT" "https://download.filezilla-project.org/client/FileZilla_3.68.1_win64-setup.exe"
wget $WGET_FLAGS -O "$BASE_DIR/NotepadPlusPlus/npp_setup.exe" "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.7.7/npp.8.7.7.Installer.x64.exe"
wget $WGET_FLAGS -O "$BASE_DIR/AnyDesk/Windows/AnyDesk.exe" "https://download.anydesk.com/AnyDesk.exe"
wget $WGET_FLAGS -O "$BASE_DIR/AnyDesk/Mac/AnyDesk.dmg" "https://download.anydesk.com/anydesk_mac.dmg"
wget $WGET_FLAGS -O "$BASE_DIR/AnyDesk/Linux/anydesk_amd64.deb" "https://download.anydesk.com/linux/anydesk_6.3.0-1_amd64.deb"
wget $WGET_FLAGS -O "$BASE_DIR/AnyDesk/Android/AnyDesk.apk" "https://download.anydesk.com/android/anydesk-release.apk"
wget $WGET_FLAGS -O "$BASE_DIR/LibreOffice/Windows/LibreOffice_Win_x64.msi" "https://download.documentfoundation.org/libreoffice/stable/24.8.0/win/x86_64/LibreOffice_24.8.0_Win_x86-64.msi"
wget $WGET_FLAGS -O "$BASE_DIR/LibreOffice/Mac/LibreOffice_Mac_x86_64.dmg" "https://download.documentfoundation.org/libreoffice/stable/24.8.0/mac/x86_64/LibreOffice_24.8.0_MacOS_x86-64.dmg"
wget $WGET_FLAGS -O "$BASE_DIR/LibreOffice/Linux/LibreOffice_Linux_x86-64_deb.tar.gz" "https://download.documentfoundation.org/libreoffice/stable/24.8.0/deb/x86_64/LibreOffice_24.8.0_Linux_x86-64_deb.tar.gz"
wget $WGET_FLAGS -O "$BASE_DIR/WinRAR/winrar-x64-fr.exe" "https://www.win-rar.com/fileadmin/winrar-versions/winrar/winrar-x64-701fr.exe"
wget $WGET_FLAGS -O "$BASE_DIR/ISOs/Ubuntu/ubuntu-24.04-desktop-amd64.iso" "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso"
find "$BASE_DIR" -type f -size 0 -delete
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Téléchargement des standalone installers : SUCCESS" >> "$LOG_FILE"


# === Démarage du docker kiwix === #
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Démarrage du docker kiwix : PENDING" >> "$LOG_FILE"
sudo docker rm -f kiwix
sudo docker pull ghcr.io/kiwix/kiwix-serve:latest
sudo docker run -d \
  --name kiwix \
	--restart=unless-stopped \
	-p "$PortKiwix:8080" \
	-v "$PathDkKiwix:/data" \
	ghcr.io/kiwix/kiwix-serve:latest \
	/data/*.zim
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Démarrage du docker kiwix : SUCCESS" >> "$LOG_FILE"
