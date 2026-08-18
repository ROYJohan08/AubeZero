# Hades — Data Destruction & Purge Framework

**Hades** est le sous-système d'effacement et de destruction de données d'urgence du projet **AubeZero**. Conçu pour réagir immédiatement lors du déclenchement d'un code de contrainte (*Duress Code*), il regroupe l'ensemble des scripts et modules responsables de l'effacement irréversible des supports de stockage physiques, des périphériques mobiles synchronisés et des traces d'activité système.

---

## Architecture & Modules

Le framework **Hades** s'articule autour de plusieurs routines spécialisées :

```text
                        ┌────────────────────────────────┐
                        │      Service Hades Engine      │
                        │    (/etc/AubeZero/Hades/)      │
                        └───────────────┬────────────────┘
                                        │
         ┌──────────────────────────────┼──────────────────────────────┐
         ▼                              ▼                              ▼
┌─────────────────┐           ┌──────────────────┐           ┌──────────────────┐
│  Storage Erase  │           │   Mobile Purge   │           │ System Tracks    │
│    (DDay.sh)    │           │    (Mobile.sh)   │           │    (Clean.sh)    │
└────────┬────────┘           └────────┬─────────┘           └────────┬─────────┘
         │                             │                              │
         ▼                             ▼                              ▼
 Effacement matériel          Effacement à distance           Nettoyage des
 (NVMe Sanitize /             des historiques, logs           historiques, RAM
 ATA Secure Erase)            et sessions smartphones          et traces système
