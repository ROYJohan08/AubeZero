<?php
/**
 * Argos - Classe de vérification et de gestion de l'état (UpCheck)
 * @Author : ROYJohan
 * @Version : 1.4.8
 * @Date : 2026-10-13
 * @Desc : Surveillance HTTP, gestion d'état JSON, journalisation Argos et contrôle d'API par Hash
 */

class UpCheck {
    private const PROTOCOL_FILE = __DIR__ . '/State.json';   
    private const DEBUG = true;

    private string $discordWebhook = '';
    private string $watchUrl = '';
    private string $apiHash = '';
    
    public function __construct() {
        $this->chargerCredentials();
    }
    
    private function chargerCredentials(): void {
        $envFile = dirname(__DIR__) . '/credentials.env';
        if (!file_exists($envFile)) {$this->argos_log('[-]', "credentials.env file does not exist at: {$envFile}");
            return;
        }
        $lines = file($envFile, FILE_IGNORE_NEW_LINES);
        if ($lines === false) {$this->argos_log('[-]', "Failed to read credentials file: {$envFile}");
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
            // Correction ici : utilisation de $parts[1] au lieu de $parts0
            $value = trim($parts[1] ?? '', " \t\n\r\0\x0B\"'");
            
            if ($value === '') {
                $this->argos_log('[~]', "Line {$lineNumber}: Value for key '{$key}' is empty");
            }
            switch ($key) {
                case 'DISCORD_WEBHOOK':
                    $this->discordWebhook = $value;
                    $this->argos_log('[+]', "Loaded credential: DISCORD_WEBHOOK");
                break;
                case 'WATCH_URL':
                    $this->watchUrl = $value;
                    $this->argos_log('[+]', "Loaded credential: WATCH_URL");
                break;
                case 'API_HASH':
                    $this->apiHash = $value;
                    $this->argos_log('[+]', "Loaded credential: API_HASH");
                break;
                default:
                    $this->argos_log('[~]', "Line {$lineNumber}: Unknown key '{$key}'");
                break;
            }
        }
        $mandatoryKeys = [
            'discordWebhook' => 'DISCORD_WEBHOOK',
            'watchUrl'        => 'WATCH_URL',
            'apiHash'         => 'API_HASH',
        ];
        foreach ($mandatoryKeys as $property =>$envName) {
            if (empty($this->$property)) {
                $this->argos_log('[-]', "{$envName} does not exist or is empty after loading");
            }
        }
    }

    private function argos_log(string $indicateur, string $message): void {$dossierLogs = __DIR__ . '/logs';
        if (!is_dir($dossierLogs)) {
            @mkdir($dossierLogs, 0755, true);
        }
        $limitYm = (new \DateTime())->modify('-2 months')->format('Ym');
        foreach (glob($dossierLogs . '/*.log') as$fichier) {
            $nomFichier = basename($fichier, '.log');
            if (preg_match('/^\d{6}$/',$nomFichier) && $nomFichier <=$limitYm) {
                @unlink($fichier);
            }
        }
        $moisAnnee = date('Ym');
        $timestamp = date('YmdHi');$fichierLog = $dossierLogs . '/' .$moisAnnee . '.log';
        $ligneLog = "{$timestamp}-ARGOS-PROTOCOLES-{$indicateur} - {$message}\n";
        
        if ($indicateur !== "[-]" && !self::DEBUG) {
            return;
        }
        @file_put_contents($fichierLog,$ligneLog, FILE_APPEND);
    }

    public function saveState($state): bool {$this->argos_log('[~]', "Tentative de sauvegarde de l'état dans " . basename(self::PROTOCOL_FILE));
        $jsonData = json_encode($state, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_IGNORE);
        if ($jsonData === false) {
			$this->argos_log('[-]', "Échec de l'encodage JSON des données d'état : " . json_last_error_msg());
            return false;
        }
        $result = @file_put_contents(self::PROTOCOL_FILE,$jsonData);
        if ($result !== false) {
			$this->argos_log('[+]', "État sauvegardé avec succès dans State.json (" . strlen($jsonData) . " octets écrits).");
            return true;
        } else {
            $this->argos_log('[-]', "Erreur d'écriture critique lors de la sauvegarde de State.json.");
            return false;
        }
    }
    
    public function readState(): array {
        $this->argos_log('[~]', "Tentative de lecture de l'état depuis " . basename(self::PROTOCOL_FILE));
        if (!file_exists(self::PROTOCOL_FILE)) {
            $this->argos_log('[-]', "Le fichier d'état " . basename(self::PROTOCOL_FILE) . " n'existe pas.");
            return [];
        }
        $content = @file_get_contents(self::PROTOCOL_FILE);
        if ($content === false) {$this->argos_log('[-]', "Erreur de lecture impossible pour le fichier " . basename(self::PROTOCOL_FILE));
            return [];
        }
        if (trim($content) === '') {$this->argos_log('[~]', "Le fichier " . basename(self::PROTOCOL_FILE) . " est vide.");
            return [];
        }
        $data = json_decode($content, true, 512, JSON_INVALID_UTF8_IGNORE);
        if (json_last_error() !== JSON_ERROR_NONE) {
            $this->argos_log('[-]', "Erreur de décodage JSON pour State.json : " . json_last_error_msg());
            return [];
        }
        $this->argos_log('[+]', "État lu et décodé avec succès depuis State.json (" . count($data) . " éléments trouvés).");
        return is_array($data) ?$data : [];
    }

    private function verifierHash(string $hashIdentification): bool {
        if (empty($this->apiHash)) {$this->argos_log('[-]', "apiHash does not exist");
            return false;
        }
        if (password_verify($hashIdentification, $this->apiHash)) {$this->argos_log('[+]', "Hash match");
            return true;
        }
        $this->argos_log('[~]', "hash doesn't match");
        return false;
    }

    public function activate(string $hashIdentification): bool {$this->argos_log('[~]', "Tentative d'activation du service via API.");
        if (!$this->verifierHash($hashIdentification)) {$this->argos_log('[-]', "Échec de l'activation : Hash API invalide.");
            return false;
        }

        $currentState = $this->readState();
		$oldstate = $currentState['is_up'];
		$currentState['is_up'] = true;
        $currentState['last_check'] = date('c');$success = $this->saveState($currentState);
        if ($success) {
			$this->argos_log('[+]', "Service activé avec succès (is_up => true).");
			if(!$oldstate){
				$this->envoyerNotificationDiscord(
					"Service activé manuellement", 
					"Le service `{$this->watchUrl}` a été activé manuellement !", 
					"15158332"
				);
			}
        }
        
        return $success;
    }

    public function desactivate(string $hashIdentification): bool {$this->argos_log('[~]', "Tentative de désactivation du service via API.");
        if (!$this->verifierHash($hashIdentification)) {
			$this->argos_log('[-]', "Échec de la désactivation : Hash API invalide.");
            return false;
        }
        $currentState = $this->readState();
		$oldstate = $currentState['is_up'];
		$currentState['is_up'] = false;
        $currentState['last_check'] = date('c');
		$success = $this->saveState($currentState);
        if ($success) {
			$this->argos_log('[+]', "Service désactivé avec succès (is_up => false).");
			if($oldstate){
				$this->envoyerNotificationDiscord(
					"Service desactivé manuellement", 
					"Le service `{$this->watchUrl}` a été desactivé manuellement !", 
					"15158332"
				);
			}
        }
        return $success;
    }
    
    private function envoyerNotificationDiscord(string $titre, string $message, string$couleur = "3447003"): void {
        if (empty($this->discordWebhook)) {$this->argos_log('[-]', "Discord Webhook non configuré dans credentials.env.");
            return;
        }
        $payloadArray = [
            "embeds" => [
                [
                    "title" => "?? ARGOS // " . $titre,
                    "description" => $message,
                    "color" => (int)$couleur,
                    "timestamp" => date('c')
                ]
            ]
        ];
        $payload = json_encode($payloadArray, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_IGNORE);
        $ch = curl_init($this->discordWebhook);
        curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "POST");
        curl_setopt($ch, CURLOPT_POSTFIELDS,$payload);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
        curl_setopt($ch, CURLOPT_TIMEOUT, 5);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $curlError = curl_error($ch);
        curl_close($ch);
        if ($httpCode >= 200 && $httpCode < 300) {$this->argos_log('[+]', "Notification Discord envoyée avec succès (Code HTTP: {$httpCode}).");
        } else {
            $this->argos_log('[-]', "Échec envoi Discord. Code HTTP: {$httpCode} | Erreur cURL: {$curlError} \vert{} Réponse: {$response}");
        }
    }
        
    private function checkHttp(string $url, int $timeout = 5): array {$this->argos_log('[~]', "Vérification HTTP en cours pour l'URL : {$url}");
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_TIMEOUT        => $timeout,
            CURLOPT_CONNECTTIMEOUT => $timeout,
            CURLOPT_NOBODY         => true,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_SSL_VERIFYPEER => false,
        ]);
        curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $errorMsg = curl_error($ch);
        curl_close($ch);$isUp = ($httpCode >= 200 &&$httpCode < 400);

        if ($isUp) {$this->argos_log('[+]', "Vérification HTTP réussie pour {$url} (Code: {$httpCode})");
        } else {
            $this->argos_log('[-]', "Échec de la vérification HTTP pour {$url} (Code: {$httpCode}, Erreur: {$errorMsg})");
        }

        return [$isUp, $httpCode,$errorMsg];
    }
    
    public function UpCheck(): void {
        if (empty($this->watchUrl)) {$this->argos_log('[-]', "WATCH_URL non définie, impossible d'effectuer la vérification.");
            return;
        }
        $return = $this->checkHttp($this->watchUrl);
        $isUp =$return[0];
        $httpCode =$return[1];

        $currentState = $this->readState();$wasUp = isset($currentState['is_up']) ?$currentState['is_up'] : true;

        if ($wasUp && !$isUp) {$this->envoyerNotificationDiscord(
                "Service Indisponible", 
                "Le service `{$this->watchUrl}` est passé hors ligne !\nCode HTTP : {$httpCode}", 
                "15158332"
            );
            $this->saveState(['is_up' => false, 'http_code' =>$httpCode, 'last_check' => date('c')]);
        } 
        elseif (!$wasUp && $isUp) {$this->envoyerNotificationDiscord(
                "Service Rétabli", 
                "Le service `{$this->watchUrl}` est de nouveau opérationnel.\nCode HTTP : {$httpCode}", 
                "3066993"
            );
            $this->saveState(['is_up' => true, 'http_code' =>$httpCode, 'last_check' => date('c')]);
        } 
        else {
            if (empty($currentState)) {$this->saveState(['is_up' => $isUp, 'http_code' =>$httpCode, 'last_check' => date('c')]);
            }
        }
    }
}
