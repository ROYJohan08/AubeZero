<?php
/****************************************************
 * Surveillance HTTP + Alerte Discord + Logs Web
 * Auteur : ROYJohanInfo
 * Module : Argos (Projet AubeZero)
 * Exec : via cron (ex: toutes les 15 min) ou accès web
 ****************************************************/

/**
 * Charge un fichier de configuration .env basique et retourne un tableau clé-valeur
 */
function loadEnv(string $filePath): array {$env = [];
    if (!file_exists($filePath)) {
        return $env;
    }

    $lines = file($filePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as$line) {
        $line = trim($line);

        // Ignorer les commentaires (#) et les lignes vides
        if ($line === '' || $line[0] === '#') {
            continue;
        }

        // Séparer la clé et la valeur au premier signe '='
        if (strpos($line, '=') !== false) {
            list($key, $value) = explode('=',$line, 2);
            $key = trim($key);
            $value = trim($value, " \t\n\r\0\x0B\"'"); // Nettoyer guillemets et espaces
            $env[$key] =$value;
        }
    }
    return $env;
}

// --------------------------------------------------
// Chargement de la configuration
// --------------------------------------------------
$envFile = __DIR__ . '/credentials.env';
$config  = loadEnv($envFile);

// URL à surveiller et Webhook Discord issus du fichier credentials.env
$url     =$config['URL_CHECK'] ?? "http://dsm.royjohan.fr:81";
$webhook =$config['DISCORD_WEBHOOK'] ?? "XXXXXXXXXXXXXXX";

// Timeout HTTP (en secondes)
$timeout = 5;

// Fichiers locaux de statut et de logs
$statusFile = __DIR__ . '/status.txt';$logFile    = __DIR__ . '/history.log';

/**
 * Ajoute une ligne horodatée au fichier de log
 */
function logMessage(string $file, string$text): void {
    $entry = "[" . date('Y-m-d H:i:s') . "] " . $text . PHP_EOL;
    file_put_contents($file,$entry, FILE_APPEND);
}

/**
 * Vérifie si l’URL répond avec un code HTTP valide
 */
function checkHttp(string $url, int$timeout = 5): array {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_TIMEOUT,$timeout);
    curl_setopt($ch, CURLOPT_CONNECTTIMEOUT,$timeout);
    curl_setopt($ch, CURLOPT_NOBODY, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $errorMsg = curl_error($ch);
    curl_close($ch);

    $isUp = ($httpCode >= 200 &&$httpCode < 400);
    return [$isUp, $httpCode,$errorMsg];
}

/**
 * Envoie un message sur Discord via Webhook
 */
function sendDiscordAlert(string $webhook, string$message): string {
    // S'assure que le texte passe bien en UTF-8
    $messageUtf8 = mb_convert_encoding($message, 'UTF-8', 'UTF-8');$payload = json_encode(
        ["content" => $messageUtf8],
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
    );

    if ($payload === false) {
        return "ÉCHEC Encodage JSON : " . json_last_error_msg();
    }

    $ch = curl_init($webhook);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS,$payload);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Content-Type: application/json; charset=utf-8"
    ]);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($curlError) {
        return "ÉCHEC cURL Discord : " . $curlError;
    }
    if ($httpCode < 200 || $httpCode >= 300) {
        return "ÉCHEC HTTP Discord (Code $httpCode) : " . $response;
    }

    return "Succès Discord (Code $httpCode)";
}

// --------------------------------------------------
// 1. Récupération de l'état actuel
// --------------------------------------------------
list($isUp, $httpCode,$curlError) = checkHttp($url,$timeout);
$currentStatus =$isUp ? 'UP' : 'DOWN';

// --------------------------------------------------
// 2. Lecture du dernier état connu
// --------------------------------------------------
$previousStatus = 'UP';
if (file_exists($statusFile)) {
    $previousStatus = trim(file_get_contents($statusFile));
}

// --------------------------------------------------
// 3. Traitement selon le changement d'état
// --------------------------------------------------
if ($previousStatus === 'UP' && $currentStatus === 'DOWN') {$msg = "\u{1F6A8} **Alerte : Service hors ligne**\nLe service `$url` ne répond plus ! (Code HTTP: $httpCode)";
    $discordResult = sendDiscordAlert($webhook,$msg);
    logMessage($logFile, "CHANGEMENT D'ÉTAT -> DOWN (Code HTTP: $httpCode, Err: $curlError) - Notification :$discordResult");

} elseif ($previousStatus === 'DOWN' && $currentStatus === 'UP') {$msg = "\u{2705} **Rétablissement : Service de nouveau en ligne**\nLe service `$url` répond correctement. (Code HTTP: $httpCode)";
    $discordResult = sendDiscordAlert($webhook,$msg);
    logMessage($logFile, "CHANGEMENT D'ÉTAT -> UP (Code HTTP: $httpCode) - Notification :$discordResult");

} else {
    logMessage($logFile, "CHECK : Service $currentStatus (Code HTTP:$httpCode) - Aucun changement");
}

// --------------------------------------------------
// 4. Mise à jour du fichier d'état
// --------------------------------------------------
file_put_contents($statusFile,$currentStatus);

// --------------------------------------------------
// 5. Affichage Web des logs (si exécuté depuis un navigateur)
// --------------------------------------------------
if (php_sapi_name() !== 'cli') {
    header('Content-Type: text/html; charset=utf-8');
    ?>
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="UTF-8">
        <title>Logs de surveillance DSM - Argos</title>
        <style>
            body { font-family: monospace; background: #121212; color: #00ff66; padding: 20px; }
            h2 { color: #fff; border-bottom: 1px solid #333; padding-bottom: 10px; }
            .status { font-weight: bold; padding: 8px 12px; border-radius: 4px; display: inline-block; margin-bottom: 15px; }
            .up { background: #1b5e20; color: #fff; }
            .down { background: #b71c1c; color: #fff; }
            pre { background: #1e1e1e; padding: 15px; border-radius: 5px; color: #ddd; overflow-x: auto; max-height: 500px; }
        </style>
    </head>
    <body>
        <h2>Surveillance Service : <?= htmlspecialchars($url) ?></h2>
        <div>
            Statut actuel : <span class="status <?= strtolower($currentStatus) ?>"><?= $currentStatus ?> (Code <?= $httpCode ?>)</span>
        </div>
        <h3>Historique des logs :</h3>
        <pre><?= file_exists($logFile) ? htmlspecialchars(file_get_contents($logFile)) : "Aucun log pour le moment." ?></pre>
    </body>
    </html>
    <?php
}
