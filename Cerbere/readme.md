# Module Cerbere — Le Coffre-Fort Numérique

> *"Je suis le gardien des secrets d'AubeZero. Mes chaînes sont impénétrables et mes registres sont incorruptibles."*

## Fonction
Je suis le module de stockage sécurisé des accès, des accréditations et de la résilience du système. Je protège les données d'authentification critiques, assure la traçabilité des opérations et garantis la survie ou la destruction ciblée de l'infrastructure en cas d'intrusion.

## Fonctionnalités principales
* **Gestion des accréditations & Mots de passe :** Centralisation, injection sécurisée et recherche distribuée du fichier `credentials.sh` à travers les différents volumes du système.
* **Procédure de Duresse (Duress Code) :** Détection d'authentification sous contrainte via PAM (`pam_exec.so`), vérification du hash SHA-256 et déclenchement d'alertes réseau d'urgence avec instanciation du protocole *Hades DDay*.
* **Watchdog & Auto-Guérison Réseau :** Surveillance continue de la charge, de la mémoire et de la connectivité réseau avec relance automatique de `systemd-networkd` et protection contre les blocages noyau (*Kernel Panic / OOM*).
* **Traçabilité & Journalisation (Mnemosyne) :** Enregistrement horodaté et infalsifiable de toutes les étapes d'installation, des incidents réseau et des événements de duresse.

---

## Architecture des Fichiers

```text
/etc/AubeZero/
├── Cerbere/
│   ├── credentials.sh     # Accréditations et secrets système chiffrés
│   ├── duress.sh          # Traitement et déclenchement du protocole duresse
│   ├── duress_pam.sh      # Wrapper d'interception PAM pour le compte 'duress'
│   └── fix-network.sh     # Script de réparation et de test réseau pour le Watchdog
└── Mnemosyne/
    └── YYYY-MM.log        # Registre mensuel des journaux d'événements
