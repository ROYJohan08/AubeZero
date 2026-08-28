# Module Hermès — Le Messager

> *"Messager des dieux et arpenteur des ombres, j'ouvre les voies de communication vers l'extérieur. Rien ne m'arrête, rien ne me censure, rien ne me traque."*

## Fonction
Je suis le module dédié aux communications à distance, à l'anonymisation et à la souveraineté hertzienne et réseau du système AubeZero. Mon rôle est de garantir des canaux de communication bidirectionnels, chiffrés et résilients entre l'infrasructure locale et le monde extérieur, même en cas de censure, d'isolement du réseau ou de surveillance ciblée.

## Fonctionnalités principales
* **Relais & Anonymisation TOR :** Déploiement et gestion d'un nœud/relais TOR (et services cachés `.onion`) pour chiffrer, masquer et isoler le trafic sortant et entrant d'AubeZero.
* **Réception & Émission Hertzienne (SDR) :** Exploitation de modules Software Defined Radio (RTL-SDR, HackRF) pour intercepter, écouter ou émettre sur des fréquences radio (décodage de télémétrie, signaux d'urgence, bandes radioamateurs, images météo NOAA).
* **Messagerie Chiffrée & Décentralisée :** Administration de passerelles de communication sécurisées (Matrix/Element, Signal-CLI, Nostr ou serveurs SMTP/IMAP chiffrés) pour l'envoi d'alertes distantes et la télécommande du système par messages chiffrés de bout en bout.
* **Réseau Maillé & VPN Résilient :** Gestion des connexions pair-à-pair et des réseaux de secours (WireGuard, Tailscale, Yggdrasil ou Reticulum) pour maintenir le contact avec les autres nœuds AubeZero sans dépendre des infrastructures Internet classiques.

## Architecture des Services

| Service | Rôle et Description |
| :--- | :--- |
| **Tor** | Serveur et nœud relais TOR pour l'anonymisation du trafic et l'hébergement de services masqués. |
| **RadioWeb** | Interface et serveur de transmission/réception réseau via des liaisons radio longue portée. |
| **SignalServ** | Passerelle de messagerie instantanée sécurisée et chiffrée de bout en bout pour la transmission d'alertes et d'ordres. |
| **SecretMail** | Serveur de courrier électronique privé, chiffré et auto-hébergé. |
| **Proxy** | Serveur proxy web privé assurant le filtrage, le masquage des en-têtes et le relais des requêtes réseau. |
