#!/bin/bash

if [ "$EUID" -ne 0 ]; then 
    echo "Droits insuffisants. Veuillez exécuter ce script en tant que root."
    exit 1
fi
LOG_DIR="/etc/AubeZero/Mnemosyne"
LOG_FILE="$LOG_DIR/$(date +%Y-%m).log"
Programme="Hades-DDay"
BASE="/media"

echo "$(date +'%Y%m%d%H:%M')-${Programme}-Suppression : PENDING" >> "$LOG_FILE"
for dir in "$BASE"/*; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    [[ "$name" == .* ]] && continue
    if [[ "$name" == Films* || "$name" == Series* || "$name" == Docs* ]]; then
        raw_disk=$(lsblk -no PKNAME "$dir" 2>/dev/null | head -n1)
        [ -z "$raw_disk" ] && raw_disk=$(lsblk -no KNAME "$dir" 2>/dev/null | head -n1)
        [ -z "$raw_disk" ] && continue
        clean_disk=$(echo "$raw_disk" | sed -E 's/p?[0-9]+$//')
        disk="/dev/$clean_disk"
        [ -b "$disk" ] || continue
        if [[ "$disk" == /dev/nvme* ]]; then
            nvme sanitize "$disk" --sanact=2 --ause=1 --owpass=1
        else
            hdparm --user-master u --security-set-pass p "$disk"
            hdparm --user-master u --security-erase p "$disk"
        fi
    fi
done
sudo rm -rf /media/Runable/DownBox/* &
echo "$(date +'%Y%m%d%H:%M')-${Programme}-Suppression : SUCCESS" >> "$LOG_FILE"
