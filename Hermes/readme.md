# Module Hermes — Le Messager Divin & Télécommunications Résilientes

> *"Messager des dieux et arpenteur des ombres, j'ouvre les voies de communication vers l'extérieur. Rien ne m'arrête, rien ne me censure, rien ne me traque."*

## Fonction
Je suis le sous-programme d'AubeZero dédié aux communications à distance, à l'anonymisation et à la souveraineté hertzienne et réseau. Mon rôle est de garantir un canal de communication bidirectionnel, chiffré et résilient entre le serveur local et le reste du monde, même en cas de censure, de coupure réseau ou de surveillance ciblée.

## Fonctionnalités principales
* **Relais & Anonymisation TOR :** Déploiement et gestion d'un nœud/relais TOR (ou services cachés `.onion`) pour chiffrer et masquer le trafic sortant et entrant d'AubeZero.
* **Réception & Émission Hertzienne (SDR - Software Defined Radio) :** Intégration de clés SDR (RTL-SDR, HackRF, etc.) pour intercepter, écouter ou émettre sur des fréquences radio (décodage de télémétrie, signaux d'urgence, bandes radioamateurs, images météo NOAA).
* **Messagerie Chiffrée & Décentralisée :** Administration de passerelles de messagerie sécurisée (Matrix/Element, Signal-CLI, Nostr ou serveurs SMTP/IMAP chiffrés) pour l'envoi d'alertes distantes et le contrôle à distance par messages chiffrés de bout en bout.
* **Réseau Maillé & VPN Résilient :** Gestion des connexions pair-à-pair et des réseaux de secours (WireGuard, Tailscale, Yggdrasil ou Reticulum) pour maintenir le contact avec les autres nœuds AubeZero sans dépendre d'Internet.

---

## Architecture des Fichiers

```text
/etc/AubeZero/
├── Hermes/
│   ├── install.sh         # Script d'installation des dépendances télécom & SDR
│   ├── README.md          # Documentation du module Hermes
│   ├── tor/               # Configuration du service et des Onion Services
│   ├── sdr/               # Scripts et outils de traitement du signal radio
│   └── messaging/         # Passerelles de messagerie chiffrée & alertes
└── Mnemosyne/
    └── YYYY-MM.log        # Registre d'événements et de métriques réseau
