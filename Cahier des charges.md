# Cahier des Charges - Projet AubeZero

## 1. Présentation Générale du Projet

### 1.1 Objectif

Le projet AubeZero est une suite d'outils automatisés en scripts Shell POSIX (`.sh`) conçue pour le déploiement, la gestion des dépendances, l'exécution autonome et la journalisation centralisée sous environnement Linux.

### 1.2 Principes Fondamentaux

* **Rigueur et Robustesse :** Langage Shell POSIX (`#!/bin/sh`), sans dépendance exclusive à Bash.

* **Architecture Modulaire :** Répartition claire entre un orchestrateur principal (**Agora**), une gestion centralisée des accès/variables (**Cerbère**) et un système de journalisation (**Mnémosyne**).

* **Autonomie et Résilience Hors-Ligne :** Le serveur doit pouvoir être déconnecté d'Internet à tout moment. Si Internet est accessible, les scripts mettent à jour les composants et ressources. Si Internet est indisponible, le système bascule automatiquement sur les fichiers et paquets déjà présents en local pour garantir un fonctionnement optimal sans interruption.

* **Mode Silencieux (Quiet Mode) :** Aucun affichage sur la sortie standard (`stdout`). Seules les erreurs graves/critiques sont envoyées vers la sortie d'erreur (`stderr`).

* **Format des Logs Strict :** Enregistrement de tous les événements dans le chemin spécifié par `PATH_MNEMOSYNE` avec des préfixes normés.

## 2. Architecture des Sous-Modules

```
/etc/AubeZero/
└── Cerbere/
    └── credentials.env     # Stockage centralisé des variables d'environnement

PATH_MNEMOSYNE/              # Dossier de destination des logs (défini dans credentials.env)
└── YYYYMMDD-[SOUS-PROGRAMME]-[SOUS-SOUS-PROGRAMME].log

```

### 2.1 Agora (Orchestrateur & Installation)

* **Rôle :** Point d'entrée principal du projet.

* **Fonctionnalités :**

  * **Vérification et installation globale :** Détection des prérequis système (outils de base, dépendances).

  * **Téléchargement et mise à jour :**

    * Test de la connectivité Internet.

    * **Si Internet est disponible :** Téléchargement ou mise à jour des sous-modules et composants.

    * **Si Internet est indisponible :** Ignorer les étapes de mise à jour/téléchargement réseau et utiliser directement la version locale des scripts, paquets et fichiers déjà présents.

  * **Orchestration :** Appels successifs des sous-modules nécessaires.

### 2.2 Cerbère (Gestion de la Configuration)

* **Rôle :** Chargement et gestion résiliente des variables d'environnement.

* **Emplacement officiel :** `/etc/AubeZero/Cerbere/credentials.env`

* **Comportement :**

  * Vérifier la présence du fichier de configuration.

  * Si le fichier ou une variable donnée est absent(e), appliquer la valeur par défaut codée en dur dans les scripts.

  * Créer le dossier `/etc/AubeZero/Cerbere/` et le fichier `credentials.env` s'ils n'existent pas encore.

### 2.3 Mnémosyne (Système de Journalisation)

* **Rôle :** Centralisation et formatage des journaux d'exécution (logs).

* **Emplacement des logs :** Défini par la variable `PATH_MNEMOSYNE` (avec valeur par défaut si non spécifiée).

* **Format du nom de fichier :** `AAAAMMDD-[SOUS-PROGRAMME]-[SOUS-SOUS-PROGRAMME].log` (ex: `20260918-AGORA-INSTALL.log`)

## 3. Spécifications Techniques et Contraintes

### 3.1 Structure et En-tête des Fichiers (Header)

Chaque programme ou script Shell faisant partie du projet AubeZero doit impérativement comporter un en-tête normalisé au tout début du fichier, respectant la structure suivante :

```
#!/bin/sh
# [Nom du module] - [Nom du programme]
# @Author : ROYJohan
# @Version : [version]
# @Date : [Date au format AAAA-MM-DD]
# @Desc : [Description du programme]

```

### 3.2 Langage et Compatibilité

* **Langage exclusif :** Shell POSIX (`#!/bin/sh`).

* Aucune extension spécifique à Bash (`[[ ]]`, tableaux/arrays, etc.) ne doit être utilisée afin de garantir une portée universelle sur tout système UNIX/Linux.

### 3.3 Gestion du Réseau et Mode Hors-Ligne (Air-Gap)

* **Détection du réseau :** Chaque opération nécessitant du réseau doit préalablement tester la connectivité (ex: test de ping ou de résolution DNS à timeout court).

* **Comportement hybride :**

  * **En ligne :** Synchroniser/mettre à jour les sous-modules, télécharger les paquets requis.

  * **Hors ligne :** Passer silencieusement l'étape de mise à jour réseau sans générer d'erreur bloquante et poursuivre l'exécution avec la copie locale disponible.

### 3.4 Gestion de l'Affichage et des Sorties (Mode Silencieux)

* **`stdout` (Sortie standard) :** Redirigée intégralement vers `/dev/null` ou vers le fichier de log Mnémosyne. Aucun texte ne doit apparaître à l'écran en fonctionnement normal.

* **`stderr` (Sortie d'erreur) :** Réservée exclusivement aux erreurs graves/critiques provoquant l'arrêt d'un sous-programme ou un dysfonctionnement majeur.

* En cas d'erreur grave, le message d'erreur est envoyé sur `stderr` et l'exécution s'interrompt avec un code d'erreur non nul (`exit 1` ou supérieur).

### 3.5 Autonomie des Sous-Modules

Chaque sous-module doit être autonome :

1. Il doit charger `credentials.env` (ou utiliser ses valeurs par défaut).

2. Il doit vérifier ses propres prérequis système et tenter de les installer/créer localement si nécessaire.

3. Si l'installation d'un prérequis nécessite du réseau et qu'Internet est indisponible, le sous-module vérifie si l'outil local existant est utilisable ; à défaut, il enregistre un échec `[-]` et s'interrompt.

## 4. Normalisation des Logs (Mnémosyne)

Chaque ligne écrite dans le fichier de log doit respecter la convention stricte suivante :

```
[INDICATEUR] - Message de log

```

### Table des Indicateurs

| **Symbolique** | **Signification** | **Utilisation** | 
| `[👉]` | Début de programme | Marque le lancement d'un sous-module ou d'un processus. | 
| `[+]` | Partie réussie | Étape validée avec succès. | 
| `[~]` | Partie échouée (Action secondaire) | Échec d'une étape non critique n'interrompant pas le programme (ex: échec de mise à jour réseau basculant sur la version locale). | 
| `[-]` | Échec fatal | Échec critique provoquant la fin prématurée du programme. | 
| `[✓]` | Fin de programme | Marque la fermeture réussie d'un sous-module. | 
