# Module Cerbère — Le Coffre-Fort Numérique

> *"Gardien incorruptible des accès et de la santé du système, je surveille les seuils d'AubeZero. Nul ne franchit mes portes sans autorisation, et toute anomalie déclenche ma vigie ultime."*

## Fonction
Je suis le module de sécurité opérationnelle, de contrôle d'accès et de surveillance continue d'AubeZero. Mon rôle est d'assurer la protection des identifiants secrets, de surveiller la santé matérielle et logicielle des infrastructures, et de déclencher des mécanismes d'isolation et de coupure physique ou logique immédiate en cas d'intrusion ou de dysfonctionnement critique.

## Fonctionnalités principales
* **Gestion Centralisée des Secrets (Creds) :** Stockage coffre-fort sécurisé, chiffré et compartimenté de l'ensemble des clés d'accès, mots de passe et jetons d'authentification du système.
* **Protocoles de Duress Unifiés (Duress) :** Intégration du système de sous-contrainte partagé avec le module Hadès, permettant de réagir silencieusement à une saisie de code sous menace ou intrusion physique.
* **Supervision Métrique & Matérielle (Glances) :** Métrologie temps réel surveillant les ressources système (charge CPU, température, mémoire, disques et interfaces réseau).
* **Orchestration & Surveillance des Conteneurs (Portainer) :** Interface et contrôle continus du parc de conteneurs applicatifs (Docker) assurant la santé des services en exécution.
* **Watchdog de Secours & Isolation d'Urgence (Watchdog) :** Disjoncteur logique et matériel autonome capable d'interrompre l'alimentation ou de couper les flux réseau instantanément en cas de défaillance critique, d'anomalie système ou de rupture de sécurité.

## Architecture des Services

| Service | Rôle et Description |
| :--- | :--- |
| **Creds** | Coffre-fort chiffré centralisé (vault) pour la gestion des mots de passe, identifiants et clés de chiffrement d'AubeZero. |
| **Duress** | Interface partagée avec Hadès déclenchant des protocoles de leurre ou de sécurité avancée lors d'une saisie de mot de passe sous contrainte. |
| **Glances** | Module de supervision matérielle pour l'analyse en temps réel des métriques du serveur et des composants logiques. |
| **Portainer** | Gestionnaire et moniteur d'orchestration Docker assurant le contrôle de l'état des conteneurs applicatifs et de leurs réseaux. |
| **Watchdog** | Système de sécurité matérielle et logicielle (*kill-switch*) exécutant une coupure d'urgence pour préserver le système en cas d'anomalie critique. |
