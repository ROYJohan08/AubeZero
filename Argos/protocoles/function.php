<?php
	/**
	 * Argos - Fonctions de gestion des Protocoles
	 * @Author : ROYJohan
	 * @Version : 2.1.0
	 * @Date : 2026-10-12
	 * @Desc : Gestion CRUD, chiffrement AES-CBC dynamique (GPS_HASH), authentification API (API_HASH), Discord et Home Assistant
	*/
	class Protocoles {
		private const DEBUG = true;
		private const PROTOCOL_FILE = __DIR__ . '/Protocoles.json';   
		private string $discordWebhook = '';
		private string $apiHash = '';
		private string $gpsHash = '';
		private string $homeAssistantToken = '';
		private string $homeAssistantUrl = '';
		public function __construct() {
			$this->chargerCredentials();
		}
		
		private function chargerCredentials(): void {
			$envFile = dirname(__DIR__) . '/credentials.env';
			if (!file_exists($envFile)) {
				$this->argos_log('[-]', "credentials.env file does not exist at: {$envFile}");
				return;
			}
			$lines = file($envFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
			if ($lines === false) {
				$this->argos_log('[-]', "Failed to read credentials file: {$envFile}");
				return;
			}
			$this->argos_log('[+]', "Loading credentials from {$envFile} (" . count($lines) . " lines)");
			foreach ($lines as $index => $line) {
				$lineNumber = $index + 1;
				$line = trim($line);
				if (empty($line) || $line[0] === '#') {
					continue;
				}
				$parts = explode('=', $line, 2);
				if (count($parts) !== 2) {
					$this->argos_log('[~]', "Line {$lineNumber}: Invalid format (missing '='): '{$line}'");
					continue;
				}
				$key = trim($parts[0]);
				$value = trim($parts[1], " \t\n\r\0\x0B\"'");
				if ($value === '') {
					$this->argos_log('[~]', "Line {$lineNumber}: Value for key '{$key}' is empty");
				}
				switch ($key) {
					case 'DISCORD_WEBHOOK':
						$this->discordWebhook = $value;
						$this->argos_log('[+]', "Loaded credential: DISCORD_WEBHOOK");
					break;
					case 'API_HASH':
						$this->apiHash = $value;
						$this->argos_log('[+]', "Loaded credential: API_HASH");
					break;
					case 'GPS_HASH':
						$this->gpsHash = $value;
						$this->argos_log('[+]', "Loaded credential: GPS_HASH");
					break;
					case 'HOMEASSISTANT_TOKEN':
						$this->homeAssistantToken = $value;
						$this->argos_log('[+]', "Loaded credential: HOMEASSISTANT_TOKEN");
					break;
					case 'HOMEASSISTANT_URL':
						$this->homeAssistantUrl = $value;
						$this->argos_log('[+]', "Loaded credential: HOMEASSISTANT_URL");
					break;
					default:
						$this->argos_log('[~]', "Line {$lineNumber}: Unknown key '{$key}'");
					break;
				}
			}
			$mandatoryKeys = [
				'discordWebhook' => 'DISCORD_WEBHOOK',
				'apiHash'        => 'API_HASH',
				'gpsHash'        => 'GPS_HASH',
				'homeAssistantToken' => 'HOMEASSISTANT_TOKEN',
				'homeAssistantUrl'   => 'HOMEASSISTANT_URL',
			];
			foreach ($mandatoryKeys as $property => $envName) {
				if (empty($this->$property)) {
					$this->argos_log('[-]', "{$envName} does not exist or is empty after loading");
				}
			}
		}

		private function argos_log(string $indicateur, string $message): void {
			$dossierLogs = __DIR__ . '/logs';
			if (!is_dir($dossierLogs)) {
				@mkdir($dossierLogs, 0755, true);
			}
			$limitYm = (new \DateTime())->modify('-2 months')->format('Ym');
			foreach (glob($dossierLogs . '/*.log') as $fichier) {
				$nomFichier = basename($fichier, '.log');
				if (preg_match('/^\d{6}$/', $nomFichier) && $nomFichier <= $limitYm) {
					@unlink($fichier);
				}
			}
			$moisAnnee = date('Ym');
			$timestamp = date('YmdHi');
			$fichierLog = $dossierLogs . '/' . $moisAnnee . '.log';
			$ligneLog = "{$timestamp}-ARGOS-PROTOCOLES-{$indicateur} - {$message}\n";
			if ($indicateur !== "[-]" && !self::DEBUG) {
				return;
			}
			@file_put_contents($fichierLog, $ligneLog, FILE_APPEND);
		}
		
		private function verifierHash(string $hashIdentification): bool {
			if (empty($this->apiHash)) {
				$this->argos_log('[-]', "apiHash does not exist");
				return false;
			}
			if (password_verify($hashIdentification, $this->apiHash)) {
				$this->argos_log('[+]', "Hash match");
				return true;
			}
			$this->argos_log('[~]', "hash dosen't match");
			return false;
		}

		private function envoyerNotificationDiscord(string $titre, string $message, string $couleur = "3447003"): void {
			if (empty($this->discordWebhook)) {
				$this->argos_log('[-]', "Discord Webhook non configurÃ© dans credentials.env.");
				return;
			}
			$payloadArray = [
				"embeds" => [
					[
						"title" => "í ½íº¨ ARGOS // " . $titre,
						"description" => $message,
						"color" => (int)$couleur,
						"timestamp" => date('c')
					]
				]
			];
			$payload = json_encode($payloadArray, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_IGNORE);
			$ch = curl_init($this->discordWebhook);
			curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
			curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
			curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
			curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
			curl_setopt($ch, CURLOPT_TIMEOUT, 5);
			$response = curl_exec($ch);
			$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
			$curlError = curl_error($ch);
			curl_close($ch);
			if ($httpCode >= 200 && $httpCode < 300) {
				$this->argos_log('[+]', "Notification Discord envoyÃ©e avec succÃ¨s (Code HTTP: {$httpCode}).");
			} else {
				$this->argos_log('[-]', "Ã‰chec envoi Discord. Code HTTP: {$httpCode} | Erreur cURL: {$curlError} | RÃ©ponse: {$response}");
			}
		}
		
		private function declencherHomeAssistant(string $nomProtocole, bool $activation): void {
			if (!$activation) {return;}
			if (empty($this->homeAssistantUrl) || empty($this->homeAssistantToken)) {
				$this->argos_log('[-]', "Home Assistant URL ou Token non configurÃ© dans credentials.env.");
				return;
			}
			$cleanName = strtolower(trim($nomProtocole));
			$entityId = "script." . $cleanName; 
			$serviceUrl = rtrim($this->homeAssistantUrl, '/') . "/api/services/script/turn_on";
			$payload = json_encode([
				"entity_id" => $entityId
			]);
			$ch = curl_init($serviceUrl);
			curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
			curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
			curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
			curl_setopt($ch, CURLOPT_HTTPHEADER, [
				"Authorization: Bearer " . $this->homeAssistantToken,
				"Content-Type: application/json"
			]);
			curl_setopt($ch, CURLOPT_TIMEOUT, 5);
			$response = curl_exec($ch);
			$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
			$curlError = curl_error($ch);
			curl_close($ch);
			if ($httpCode >= 200 && $httpCode < 300) {
				$this->argos_log('[+]', "Script Home Assistant dÃ©clenchÃ© avec succÃ¨s pour {$entityId} (Code HTTP: {$httpCode}).");
			} else {
				$this->argos_log('[-]', "Ã‰chec dÃ©clenchement script Home Assistant ({$entityId}). Code HTTP: {$httpCode} | Erreur cURL: {$curlError} | RÃ©ponse: {$response}");
			}
		}

		private function encryptGps(string $data): string {
			if (empty($data)) {
				$this->argos_log('[-]', "encryptGps skipped: data is empty");
				return '';
			}
			if (empty($this->gpsHash)) {
				$this->argos_log('[-]', "encryptGps failed: gpsHash does not exist or is empty");
				return '';
			}
			$cipher = "aes-256-cbc";
			$this->argos_log('[~]', "GpsHash {$this->gpsHash}");
			$sha1Binary = hex2bin($this->gpsHash);
			$key = hash('sha256', $sha1Binary, true);
			$this->argos_log('[~]', "key ".bin2hex($key));
			$ivLength = openssl_cipher_iv_length($cipher);    
			if ($ivLength === false) {
				$this->argos_log('[-]', "encryptGps failed: invalid cipher length for {$cipher}");
				return '';
			}
			$iv = openssl_random_pseudo_bytes($ivLength);
			if ($iv === false) {
				$this->argos_log('[-]', "encryptGps failed: unable to generate initialization vector (IV)");
				return '';
			}
			$encryptedRaw = openssl_encrypt($data, $cipher, $key, OPENSSL_RAW_DATA, $iv);
			if ($encryptedRaw === false) {
				$this->argos_log('[-]', "encryptGps failed: openssl_encrypt error");
				return '';
			}
			$this->argos_log('[+]', "GPS data successfully encrypted");
			return base64_encode($iv . $encryptedRaw);
		}

		private function validerEtChiffrerCoordonnees(array $coordonnees): array {
			if (empty($coordonnees)) {
				$this->argos_log('[-]', "validerEtChiffrerCoordonnees skipped: coordinate array is empty");
				return [];
			}
			$coordonneesChiffrees = [];
			$totalPoints = count($coordonnees);
			$this->argos_log('[+]', "Processing {$totalPoints} coordinate point(s) for validation and encryption");
			foreach ($coordonnees as $index => $point) {
				$pointNumber = $index + 1;
				if (!is_array($point)) {
					$this->argos_log('[-]', "Point {$pointNumber}: Invalid format (expected array)");
					continue;
				}
				$hasLat = isset($point['lat']) || isset($point['latitude']);
				$hasLon = isset($point['lon']) || isset($point['lng']) || isset($point['longitude']);
				if (!$hasLat || !$hasLon) {
					$this->argos_log('[-]', "Point {$pointNumber}: Missing latitude or longitude keys");
					continue;
				}
				$lat = (string)($point['lat'] ?? $point['latitude']);
				$lon = (string)($point['lon'] ?? $point['lng'] ?? $point['longitude']);
				if (!is_numeric($lat) || !is_numeric($lon)) {
					$this->argos_log('[-]', "Point {$pointNumber}: Latitude or longitude is not numeric (lat: '{$lat}', lon: '{$lon}')");
					continue;
				}
				$encryptedLat = $this->encryptGps($lat);
				$encryptedLon = $this->encryptGps($lon);
				if ($encryptedLat === '' || $encryptedLon === '') {
					$this->argos_log('[-]', "Point {$pointNumber}: Encryption failed for coordinates");
					continue;
				}
				$coordonneesChiffrees[] = [
					'lat' => $encryptedLat,
					'lon' => $encryptedLon
				];
			}
			$successCount = count($coordonneesChiffrees);
			$this->argos_log('[+]', "Successfully encrypted {$successCount} / {$totalPoints} coordinate point(s)");
			return $coordonneesChiffrees;
		}

		public function chargerProtocoles(): array {
			$protocolFile = self::PROTOCOL_FILE;
			if (!file_exists($protocolFile)) {
				$this->argos_log('[-]', "Protocol file does not exist at: {$protocolFile}");
				return [];
			}
			$contenu = file_get_contents($protocolFile);
			if ($contenu === false) {
				$this->argos_log('[-]', "Failed to read protocol file: {$protocolFile}");
				return [];
			}
			if (trim($contenu) === '') {
				$this->argos_log('[-]', "Protocol file is empty: {$protocolFile}");
				return [];
			}
			$data = json_decode($contenu, true, 512, JSON_INVALID_UTF8_IGNORE);
			if (json_last_error() !== JSON_ERROR_NONE) {
				$jsonErrorMsg = json_last_error_msg();
				$this->argos_log('[-]', "Failed to decode JSON from protocol file: {$jsonErrorMsg}");
				return [];
			}
			if (!is_array($data)) {
				$this->argos_log('[-]', "Protocol file content is not a valid array structure");
				return [];
			}
			$totalProtocols = count($data);
			$this->argos_log('[+]', "Successfully loaded {$totalProtocols} protocol(s) from {$protocolFile}");
			return $data;
		}

		private function sauvegarderProtocoles(array $protocoles): bool {
			$protocolFile = self::PROTOCOL_FILE;
			$totalProtocols = count($protocoles);
			$this->argos_log('[+]', "Attempting to save {$totalProtocols} protocol(s) to {$protocolFile}");
			$jsonContent = json_encode($protocoles, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);    
			if (json_last_error() !== JSON_ERROR_NONE) {
				$jsonErrorMsg = json_last_error_msg();
				$this->argos_log('[-]', "Failed to encode protocols to JSON: {$jsonErrorMsg}");
				return false;
			}
			$result = file_put_contents($protocolFile, $jsonContent);
			if ($result === false) {
				$this->argos_log('[-]', "Failed to write protocol file to disk: {$protocolFile}");
				return false;
			}
			$this->argos_log('[+]', "Successfully saved protocols to {$protocolFile} ({$result} bytes written)");
			return true;
		}

		public function addProtocoles(string $nom, string $description, array $coordonnees, string $hashIdentification): array {
			$this->argos_log('[+]', "Tentative d'ajout du protocole : {$nom}");
			if (!$this->verifierHash($hashIdentification)) {
				$this->argos_log('[-]', "Ã‰chec : Hash d'identification invalide pour l'ajout du protocole '{$nom}'.");
				return ['succes' => false, 'message' => "Erreur d'authentification : Hash d'identification invalide."];
			}
			$coordsTraitees = $this->validerEtChiffrerCoordonnees($coordonnees);
			if (empty($coordsTraitees)) {
				$this->argos_log('[-]', "Ã‰chec : Aucune coordonnÃ©e valide n'a pu Ãªtre traitÃ©e pour le protocole '{$nom}'.");
				return ['succes' => false, 'message' => "Erreur : Les coordonnÃ©es fournies sont invalides ou vides."];
			}
			$protocoles = $this->chargerProtocoles();
			foreach ($protocoles as $p) {
				if (isset($p['nom']) && strcasecmp($p['nom'], $nom) === 0) {
					$this->argos_log('[-]', "Ã‰chec : Le protocole '{$nom}' existe dÃ©jÃ .");
					return ['succes' => false, 'message' => "Le protocole '{$nom}' existe dÃ©jÃ ."];
				}
			}
			$nouveauProtocole = [
				'nom' => $nom,
				'description' => $description,
				'coordonnees' => $coordsTraitees,
				'actif' => false,
				'cree_le' => date('Y-m-d H:i:s')
			];
			$protocoles[] = $nouveauProtocole;
			if ($this->sauvegarderProtocoles($protocoles)) {
				$this->argos_log('[+]', "Protocole '{$nom}' ajoutÃ© avec succÃ¨s.");
				return ['succes' => true, 'message' => "Protocole '{$nom}' ajoutÃ© avec succÃ¨s."];
			}
			$this->argos_log('[-]', "Erreur d'Ã©criture lors de l'ajout du protocole '{$nom}'.");
			return ['succes' => false, 'message' => "Erreur technique lors de l'enregistrement."];
		}

		public function deleteProtocoles(string $nom, string $hashIdentification): array {
			$this->argos_log('[+]', "Tentative de suppression du protocole : {$nom}");
			if (!$this->verifierHash($hashIdentification)) {
				$this->argos_log('[-]', "Ã‰chec : Hash d'identification invalide pour la suppression du protocole '{$nom}'.");
				return ['succes' => false, 'message' => "Erreur d'authentification : Hash d'identification invalide."];
			}
			$protocoles = $this->chargerProtocoles();
			$initialCount = count($protocoles);
			$protocolesFiltres = array_filter($protocoles, function($p) use ($nom) {
				return isset($p['nom']) && strcasecmp($p['nom'], $nom) !== 0;
			});
			if (count($protocolesFiltres) === $initialCount) {
				$this->argos_log('[-]', "Ã‰chec : Protocole '{$nom}' introuvable pour suppression.");
				return ['succes' => false, 'message' => "Protocole introuvable."];
			}
			$protocolesFiltres = array_values($protocolesFiltres);
			if ($this->sauvegarderProtocoles($protocolesFiltres)) {
				$this->argos_log('[+]', "Protocole '{$nom}' supprimÃ© avec succÃ¨s.");
				return ['succes' => true, 'message' => "Protocole '{$nom}' supprimÃ© avec succÃ¨s."];
			}
			$this->argos_log('[-]', "Erreur d'Ã©criture lors de la suppression du protocole '{$nom}'.");
			return ['succes' => false, 'message' => "Erreur technique lors de l'enregistrement."];
		}

		public function changeProtocoles(string $nom, string $description, array $coordonnees, string $hashIdentification): array {
			$this->argos_log('[+]', "Tentative de modification du protocole : {$nom}");
			if (!$this->verifierHash($hashIdentification)) {
				$this->argos_log('[-]', "Ã‰chec : Hash d'identification invalide pour la modification du protocole '{$nom}'.");
				return ['succes' => false, 'message' => "Erreur d'authentification : Hash d'identification invalide."];
			}
			$coordsTraitees = $this->validerEtChiffrerCoordonnees($coordonnees);
			if (empty($coordsTraitees)) {
				$this->argos_log('[-]', "Ã‰chec : Aucune coordonnÃ©e valide n'a pu Ãªtre traitÃ©e pour la modification du protocole '{$nom}'.");
				return ['succes' => false, 'message' => "Erreur : Les coordonnÃ©es fournies sont invalides ou vides."];
			}
			$protocoles = $this->chargerProtocoles();
			$trouve = false;
			foreach ($protocoles as &$p) {
				if (isset($p['nom']) && strcasecmp($p['nom'], $nom) === 0) {
					$p['description'] = $description;
					$p['coordonnees'] = $coordsTraitees;
					$p['modifie_le'] = date('Y-m-d H:i:s');
					$trouve = true;
					break;
				}
			}
			unset($p);
			if ($trouve && $this->sauvegarderProtocoles($protocoles)) {
				$this->argos_log('[+]', "Protocole '{$nom}' mis Ã  jour avec succÃ¨s.");
				return ['succes' => true, 'message' => "Protocole '{$nom}' mis Ã  jour avec succÃ¨s."];
			}
			$this->argos_log('[-]', "Ã‰chec : Protocole '{$nom}' introuvable pour modification.");
			return ['succes' => false, 'message' => "Protocole introuvable."];
		}

		public function activateProtocoles(string $nom, string $hashIdentification): array {
            $this->argos_log('[+]', "Tentative d'activation du protocole : {$nom}");
            if (!$this->verifierHash($hashIdentification)) {
                $this->argos_log('[-]', "Ã‰chec : Hash d'identification invalide pour l'activation du protocole '{$nom}'.");
                return ['succes' => false, 'message' => "Erreur d'authentification : Hash d'identification invalide."];
            }
            $protocoles = $this->chargerProtocoles();
            $trouve = false;
            foreach ($protocoles as &$p) {
                if (isset($p['nom']) && strcasecmp($p['nom'], $nom) === 0) {
                    $p['actif'] = true;
                    $p['modifie_le'] = date('Y-m-d H:i:s');
                    $trouve = true;
                    break;
                }
            }
            unset($p);
            if ($trouve && $this->sauvegarderProtocoles($protocoles)) {
                $this->argos_log('[+]', "Protocole '{$nom}' activÃ© avec succÃ¨s.");
                if (method_exists($this, 'envoyerNotificationDiscord')) {
                    $description = "Le protocole **{$nom}** vient d'Ãªtre activÃ© sur le rÃ©seau.\n\nðŸ”— [Voir les protocoles](http://api.royjohan.fr/protocoles)";
                    $this->envoyerNotificationDiscord("ACTIVATION DE PROTOCOLE", $description, "15158332");
                }
                if (method_exists($this, 'declencherHomeAssistant')) {
                    $this->declencherHomeAssistant($nom, true);
                }
                return ['succes' => true, 'message' => "Protocole '{$nom}' activÃ©."];
            }
            $this->argos_log('[-]', "Ã‰chec : Protocole '{$nom}' introuvable pour activation.");
            return ['succes' => false, 'message' => "Protocole introuvable."];
        }

		public function desactivate(string $nom, string $hashIdentification): array {
			$this->argos_log('[+]', "Tentative de dÃ©sactivation du protocole : {$nom}");
			if (!$this->verifierHash($hashIdentification)) {
				$this->argos_log('[-]', "Ã‰chec : Hash d'identification invalide pour la dÃ©sactivation du protocole '{$nom}'.");
				return ['succes' => false, 'message' => "Erreur d'authentification : Hash d'identification invalide."];
			}
			$protocoles = $this->chargerProtocoles();
			$trouve = false;
			foreach ($protocoles as &$p) {
				if (isset($p['nom']) && strcasecmp($p['nom'], $nom) === 0) {
					$p['actif'] = false;
					$p['modifie_le'] = date('Y-m-d H:i:s');
					$trouve = true;
					break;
				}
			}
			unset($p); 
			if ($trouve && $this->sauvegarderProtocoles($protocoles)) {
				$this->argos_log('[+]', "Protocole '{$nom}' dÃ©sactivÃ© avec succÃ¨s.");        
				if (method_exists($this, 'envoyerNotificationDiscord')) {
					$this->envoyerNotificationDiscord("DÃ‰SACTIVATION DE PROTOCOLE", "Le protocole **{$nom}** a Ã©tÃ© dÃ©sactivÃ©.", "3066993");
				}
				if (method_exists($this, 'declencherHomeAssistant')) {
					$this->declencherHomeAssistant($nom, false);
				}
				return ['succes' => true, 'message' => "Protocole '{$nom}' dÃ©sactivÃ©."];
			}
			$this->argos_log('[-]', "Ã‰chec : Protocole '{$nom}' introuvable pour dÃ©sactivation.");
			return ['succes' => false, 'message' => "Protocole introuvable."];
		}
	}
