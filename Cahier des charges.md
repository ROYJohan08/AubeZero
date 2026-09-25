# Cahier des Charges - Projet AubeZero

## 1. Présentation Générale du Projet

### 1.1 Objectif Général
Le projet **AubeZero** a pour objectif principal de maintenir une version autonome, résiliente et constamment à jour d'un serveur hébergeant une copie locale/sélectionnée d'Internet ainsi qu'une vaste base de connaissances. Le système garantit la souveraineté numérique, la pérennité des données et une capacité de fonctionnement intégrale en mode déconnecté (*air-gapped*).

### 1.2 Principes Fondamentaux

* **Souveraineté & Autonomie :** Le serveur doit pouvoir fonctionner indéfiniment sans connexion Internet. Si Internet est inaccessible, le fonctionnement n'est pas ralenti : les étapes de mise à jour réseau sont ignorées et le système s'exécute directement sur les données/ressources locales.
* **Mise à Jour Automatisée & Résiliente :** Lors du réseau disponible, l'exécution quotidienne des programmes sert à synchroniser et mettre à jour les données depuis GitHub. L'exécution répétée (ex: journalière via CRON) ne doit poser aucun problème d'idempotence ni bloquer les tâches.
* **Architecture Modulaire :** Le système est découpé en **Modules** fonctionnels (ex: Agora, Apollon, Argos, Athena, Cerbère, Hadès, Hermès, Ichnaea, Mnémosyne, Prométhée, Zeus). Chaque module regroupe un ensemble de **programmes** spécifiques.
* **Journalisation Unifiée :** Tous les programmes et modules partagent un unique fichier de log quotidien géré via **Mnémosyne**.
* **Chartes d'Interface Réduites & Normalisées :** Toutes les interfaces utilisateur respectent un style HUD militaire futuriste, minimaliste, avec fenêtre modale pour les détails et alertes style Toast Discord.

---

## 2. Architecture des Modules et Infrastructure

### 2.1 Liste des Modules du Écosystème
Le projet se compose des modules suivants :

1. **Agora :** Orchestrateur principal, déploiement et installation globale.
2. **Apollon :** Gestion et distribution des données/médias de la base de connaissances.
3. **Argos :** Surveillance, cartographie et sécurité géospatiale.
4. **Athena :** Moteur d'indexation et d'accès à la base de connaissances/Savoir.
5. **Cerbere :** Gestion centralisée des identifiants, clés et variables d'environnement.
6. **Hades :** Stockage résilient, sauvegardes et archivage de secours.
7. **Hermes :** Communications, notifications et flux réseau inter-serveurs.
8. **Ichnaea :** Traçabilité, analyse des parcours et télémétrie locale.
9. **Mnemosyne :** Système centralisé de journalisation et d'audit.
10. **Promethee :** Automatisation des tâches système, énergie et maintenance automatisée.
11. **Zeus :** Contrôle de haut niveau, arbitrage et supervision de l'écosystème.

### 2.2 Infrastructure Serveurs
L'architecture s'appuie sur deux infrastructures principales :
* **`dsm.royjohan.fr` :** Serveur NAS local hébergeant le stockage de la base de connaissances et les sauvegardes lourdes.
* **`api.royjohan.fr` :** Serveur externe OVH assurant le relais des APIs et flux externes.

---

## 3. Spécifications Techniques des Programmes

### 3.1 En-tête Réglémentaire (Header Standard)
Chaque programme ou script (Shell POSIX `#!/bin/sh` ou autre langage du projet) doit obligatoirement inclure l'en-tête normé suivant :

```sh
#!/bin/sh
# [Nom du Module] - [Nom du Programme]
# @Author  : ROYJohan
# @Version : 1.0.0
# @Date    : AAAA-MM-DD
# @Desc    : Description synthétique de la fonction du programme
```

### 3.2 Exécution Quotidienne et Indépendance Réseau
1. **Exécution Sans Erreur :** Un programme doit pouvoir être exécuté tous les jours à n'importe quel moment sans altérer l'état stabilisé du système.
2. **Mise à Jour GitHub :** Si la connectivité vers GitHub/Internet est établie, le programme télécharge/synchronise les dernières mises à jour de code et de données.
3. **Mode Local / Hors-Ligne :** Si Internet est indisponible :
   * Le test de connectivité doit échouer rapidement (timeout court).
   * L'étape de synchronisation/mise à jour est ignorée silencieusement (`[~]`).
   * Le programme s'exécute immédiatement en local sans ralentissement ni blocage.

### 3.3 Sorties Standard et Erreurs
* **Sortie Standard (`stdout`) :** Entièrement redirigée vers `/dev/null` ou vers le système de log **Mnémosyne**. Aucun affichage parasite sur le terminal en mode normal.
* **Sortie d'Erreur (`stderr`) :** Réservée uniquement aux erreurs critiques bloquantes (`exit 1` ou supérieur).

---

## 4. Système de Journalisation Centralisé (Mnémosyne)

### 4.1 Nommage du Fichier de Log
Tous les modules et programmes écrivent leurs logs dans un **unique fichier quotidien commun** nommé strictement selon la date du jour :

* **Format du nom :** `AAAAMMDD.log`
* **Exemple :** `20260924.log`
* **Chemin de stockage :** Spécifié par la variable `PATH_MNEMOSYNE` (définie dans `/etc/AubeZero/Cerbere/credentials.env`).

### 4.2 Formatage et Indicateurs des Messages
Chaque ligne ajoutée au fichier log quotidien doit être complète et respecter le format suivant :

```text
[AAAAMMDD-HHMMSS] [MODULE] [PROGRAMME] [INDICATEUR] Message explicite
```

#### Table des Indicateurs Obligatoires
| Indicateur | Signification | Cas d'utilisation |
| :---: | :--- | :--- |
| `[👉]` | **Début** | Marque l'initialisation du programme ou d'une sous-tâche critique. |
| `[+]` | **Succès** | Étape ou action validée avec succès. |
| `[~]` | **Avertissement / Contournement** | Échec non critique (ex: absence d'Internet, bascule en mode local). |
| `[-]` | **Échec Fatal** | Échec critique entraînant l'arrêt brutal du programme. |
| `[✓]` | **Fin** | Marque la fin d'exécution conforme du programme. |

---

## 5. Normalisation des Interfaces Utilisateur (UI/UX)

Toute interface graphique ou web associée à un module d'AubeZero doit obligatoirement respecter la charte graphique et ergonomique suivante :

### 5.1 Charte Visuelle et Style
* **Langue :** 100% en Français (aucun terme technique anglophone sans justification).
* **Thème Visuel :** **HUD Militaire Futuriste**, thème sombre à dominante bleue (nuances cyan, bleu néon, fond bleu très sombre/noir).
* **Philosophie d'affichage :** *Uniquement le nécessaire*. Pas de surcharge visuelle. Les écrans principaux affichent les informations essentielles d'un coup d'œil.

### 5.2 Composants Graphiques
* **Fenêtres Modales :** Utilisées pour afficher toute information complémentaire, détail de configuration, ou formulaire de saisie afin de ne pas encombrer l'écran principal.
* **Notifications d'Erreur / Toasts :** Toute notification d'erreur ou d'alerte système doit adopter le design d'un **Toast Discord** (carte escamotable en bas de page avec bande d'accentuation d'alerte).
