#!/bin/bash
set -e
PING_TARGET="192.168.1.1"
MAX_LOAD="24"
MIN_MEM="25000"
REPAIR_SCRIPT="/etc/AubeZero/Cerbere/fix-network.sh"
cat << 'EOF' | sudo tee /etc/sysctl.d/99-autoreboot.conf > /dev/null
kernel.panic = 10
kernel.hung_task_timeout_secs = 120
vm.panic_on_oom = 1
EOF
sudo sysctl --system > /dev/null
sudo apt-get update -qq
sudo apt-get install -y watchdog -qq
cat << EOF | sudo tee $REPAIR_SCRIPT > /dev/null
#!/bin/bash
LOG_FILE="/var/log/network-repair.log"
echo "\$(date) - [WATCHDOG] Perte de connexion détectée. Redémarrage de systemd-networkd..." >> "\$LOG_FILE"
sudo systemctl restart systemd-networkd
sleep 5
if ping -c 1 -W 2 $PING_TARGET > /dev/null 2>&1; then
    echo "\$(date) - [WATCHDOG] Connexion réseau rétablie avec succès." >> "\$LOG_FILE"
    exit 0
else
    echo "\$(date) - [WATCHDOG] Échec du rétablissement. Le serveur va rebooter." >> "\$LOG_FILE"
    exit 1
fi
EOF
sudo chmod +x $REPAIR_SCRIPT

if [ ! -f /etc/watchdog.conf.bak ]; then
    sudo cp /etc/watchdog.conf /etc/watchdog.conf.bak
fi
cat << EOF | sudo tee /etc/watchdog.conf > /dev/null
watchdog-device = /dev/watchdog
max-load-1 = $MAX_LOAD
min-memory = $MIN_MEM
ping = $PING_TARGET
ping-retry = 3
repair-binary = $REPAIR_SCRIPT
repair-timeout = 30
ping-retry = 3
EOF
sudo systemctl enable watchdog --now > /dev/null 2>&1
