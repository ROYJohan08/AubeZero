sudo nano /etc/sysctl.d/99-watchdog.conf
```# Redémarrer automatiquement 10 secondes après un panic du noyau
kernel.panic = 10

# Déclencher un panic si un processus reste bloqué trop longtemps (lockup)
kernel.hung_task_timeout_secs = 120```
sudo nano /etc/sysctl.d/99-oom-panic.conf
```# Déclencher un panic noyau lorsque la mémoire est totalement saturée
vm.panic_on_oom = 1```
sudo apt update && sudo apt install watchdog -y
sudo sysctl --system
