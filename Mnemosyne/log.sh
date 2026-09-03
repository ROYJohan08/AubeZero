#!/bin/bash

log() {
    echo "$(date +'%Y%m%d%H:%M')-${Programme}-$1" >> "/etc/AubeZero/Mnemosyne/$(date +%Y-%m).log"
}
