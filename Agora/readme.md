# Module Agora — L'Agora Numérique & Chef d'Orchestre

> *"Je suis le socle sur lequel repose AubeZero. J'accueille les modules, prépare le terrain et harmonise la mémoire de l'infrastructure."*

## Fonction
Je suis le module maître d'initialisation, d'orchestration et d'approvisionnement (provisioning). Je prépare l'environnement système d'Ubuntu Server, gère l'installation des dépendances matérielles et logicielles, monte automatiquement les espaces de stockage et déclenche le déploiement de tous les autres sous-programmes d'AubeZero.

## Fonctionnalités principales
* **Orchestration & Déploiement Central :** Téléchargement, distribution et exécution séquentielle des scripts d'installation des sous-modules (`Apollon`, `Athena`, `Cerbere`, `Hades`, `Hermes`, `Promethee`).
* **Gestion Dynamique des Disques (Montage Automatique) :** Détection de tous les volumes de stockage non montés, attribution de points de montage sous `/media/LABEL` (ou UUID) et écriture sécurisée dans `/etc/fstab` avec options de tolérance de panne (`nofail`, `x-systemd.device-timeout=5`).
* **Souveraineté des Environnements & Alias :** Normalisation des configurations du shell Bash (`.bashrc`) pour l'utilisateur `root` et l'ensemble des comptes utilisateurs sous `/home/`.
* **Préparation de la Pile Logicielle :** Installation et configuration du moteur Docker, des outils réseau (`net-tools`, `iperf`), du partage de fichiers (`samba`), de Python et des dépôts spécifiques (`ppa:deadsnakes`).
* **Verrouillage de la Veille Serveur :** Masquage complet des cibles Systemd de mise en veille (`suspend`, `hibernate`) pour garantir une disponibilité 24/7.

---

## Architecture des Fichiers

```text
/etc/AubeZero/
├── Agora/
│   ├── install.sh         # Master installer d'AubeZero
│   ├── README.md          # Documentation du module Agora
│   └── .bashrc            # Configuration et alias Bash unifiés
├── Apollon/
├── Athena/
├── Cerbere/
├── Hades/
├── Hermes/
├── Promethee/
└── Mnemosyne/
    └── YYYY-MM.log        # Journal de bord d'installation et d'orchestration
