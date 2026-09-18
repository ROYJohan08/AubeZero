Cahier des Charges - Projet AubeZero
1. Introduction et Présentation du Projet
1.1 Objectif Général
Le projet AubeZero est un écosystème d'automatisation et de déploiement modulaire pour environnement Linux. Il est développé exclusivement en scripts Shell POSIX (`/bin/sh`) et s'appuie sur une architecture distribuée en sous-modules autonomes.
1.2 Vocabulaire et Nomenclature
Agora : Script maître / orchestrateur d'installation.
Cerbère : Module de gestion centralisée des variables d'environnement et identifiants.
Mnémosyne : Module de traçabilité et gestion des journaux d'événements (logs).
---
2. Contraintes Techniques et Execution
2.1 Langage et Interprète
Tous les scripts du projet doivent être strictement écrits en POSIX Shell (`#!/bin/sh`) afin de garantir une portabilité maximale sans dépendre de fonctionnalités spécifiques à Bash ou Zsh.
2.2 Politique d'Affichage et Mode Silencieux
Principe du silence : Lors de l'exécution des scripts (Agora et sous-modules), aucun affichage ne doit être produit sur la sortie standard (`stdout`). Les redirections appropriées (ex: `>/dev/null`) doivent être appliquées à toutes les commandes sous-jacentes.
Gestion des erreurs critiques : Seuls les messages d'erreur graves provoquant un arrêt prématuré du programme (symbole `\\\[-]`) doivent être redirigés vers la sortie d'erreur standard (`stderr` / `\\\&2`).
Suivi d'exécution : Le suivi du déroulement des scripts se fait exclusivement via la consultation du fichier de log généré par Mnémosyne.
---
3. Architecture et Fonctionnement des Modules
3.1 Orchestrateur Central : Agora
Agora est le script d'entrée chargé de déployer l'environnement global.
Rôle principal :
Télécharger et installer l'ensemble des prérequis globaux.
Télécharger/cloner l'ensemble des sous-modules du projet AubeZero.
Lancer l'exécution de chaque sous-module.
3.2 Autonomie et Defensive Scripting des Sous-Modules
Chaque sous-module doit fonctionner de manière totalement autonome :
Vérification systématique : Au lancement, le sous-module contrôle la présence de ses prérequis système, paquets requis, fichiers et répertoires.
Auto-installation / Auto-réparation : En cas de prérequis manquant, le sous-module le télécharge, le crée ou l'installe de manière transparente sans intervention utilisateur.
---
4. Configuration Centralisée : Cerbère
4.1 Fichier de Configuration
Les variables globales, chemins et secrets sont stockés dans le fichier :
```text
/etc/AubeZero/Cerbere/credentials.env
```
4.2 Chargement et Valeurs de Repli (Fallback)
Tout script AubeZero tente de sourcer le fichier `/etc/AubeZero/Cerbere/credentials.env` dès son initialisation.
Si le fichier est absent ou qu'une variable spécifique manque, le script doit utiliser une valeur par défaut prédéfinie directement dans le script `sh`.
Cerbère (ou le sous-module actif) initialise le fichier `/etc/AubeZero/Cerbere/credentials.env` avec les valeurs par défaut si celui-ci n'existe pas.
---
5. Journalisation et Traçabilité : Mnémosyne
5.1 Emplacement des Logs
Tous les événements sont enregistrés dans un fichier situé dans le répertoire spécifié par la variable `PATH\\\_MNEMOSYNE`.
(Valeur par défaut si non définie : `/var/log/AubeZero/`).
5.2 Formatage des Entrées de Log
Chaque ligne ajoutée au fichier de log doit observer la structure exacte suivante :
```text
AAAAMMDD-\\\[SOUS-PROGRAMME]-\\\[SOUS-SOUS-PROGRAMME] - \\\[SYMBOLE] Texte
```
`AAAAMMDD` : Date du jour au format ISO basique (ex: `20260918`).
`\\\[SOUS-PROGRAMME]` : Nom du sous-module (ex: `AGORA`, `CERBERE`, `MNEMOSYNE`).
`\\\[SOUS-SOUS-PROGRAMME]` : Nom du composant ou de la fonction exécutée (ex: `CHECK-DEP`, `INSTALL`).
`\\\[SYMBOLE]` : Indicateur standard d'état.
5.3 Convention des Symboles de Log
Symbole	Usage / Signification	Impact du programme
`\\\[👉]`	Début de programme / lancement d'étape	Information (Lancement)
`\\\[+]`	Partie réussie avec succès	Succès
`\\\[\\\~]`	Partie échouée nécessitant une action secondaire / fallback	Avertissement / Récupération
`\\\[-]`	Échec grave coupant l'exécution du programme	Erreur Fatale (Sortie sur `stderr` + `exit 1`)
`\\\[✓]`	Fin du programme	Succès global (Terminé)
---
6. Exemple d'Exécution et Contenu du Log
Exécution en ligne de commande :
```sh
# Lancement totalement silencieux si aucune erreur grave ne survient
./agora.sh
```
Exemple de contenu du fichier de log (`$PATH\\\_MNEMOSYNE/aubezero.log`) :
```text
20260918-AGORA-MAIN - \\\[👉] Démarrage du déploiement AubeZero
20260918-AGORA-PREFREQ - \\\[+] Verification et installation de curl terminées
20260918-CERBERE-ENV - \\\[\\\~] credentials.env non trouvé, utilisation des valeurs par défaut
20260918-CERBERE-ENV - \\\[+] Fichier /etc/AubeZero/Cerbere/credentials.env initialisé
20260918-SUBMODULE1-DEP - \\\[+] Dépendances validées
20260918-AGORA-MAIN - \\\[✓] Déploiement AubeZero terminé avec succès
```
