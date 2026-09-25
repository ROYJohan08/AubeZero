<?php
/*******************************************************************************
 * [Argos] - [surveillance_http.php]
 * @Author  : ROYJohan
 * @Version : 1.2
 * @Date    : 2026-09-25
 * @Desc    : Surveillance HTTP du service DSM, alerte Discord et restitution HUD Web.
 *******************************************************************************/

/**
 * Charge la configuration d'environnement .env (POSIX / AubeZero)
 */
function loadEnv(string $filePath): array {$env = [];
    if (!file_exists($filePath)) {
        return $env;
    }

    $lines = file($filePath, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    foreach ($lines as$line) {
        $line = trim($line);
        if ($line === '' || $line[0] === '#') {
            continue;
        }
        if (strpos($line, '=') !== false) {
            list($key, $value) = explode('=',$line, 2);
            $key = trim($key);
            $value = trim($value, " \t\n\r\0\x0B\"'");
            $env[$key] =$value;
        }
    }
    return $env;
}

// --------------------------------------------------
// 1. CHARGEMENT DE LA CONFIGURATION (CERBÈRE)
// --------------------------------------------------
$envFile = '/etc/AubeZero/Cerbere/credentials.env';
if (!file_exists($envFile)) {$envFile = __DIR__ . '/credentials.env';
}
$config = loadEnv($envFile);

// Chemins et variables d'environnement
$pathMnemosyne =$config['PATH_MNEMOSYNE'] ?? './';
$url           =$config['URL_CHECK']      ?? "http://dsm.royjohan.fr:81";
$webhook       =$config['DISCORD_WEBHOOK']  ?? "";
$timeout       = 5;
$statusFile    = __DIR__ . '/status.txt';

// S'assurer de l'existence du dossier Mnémosyne
if (!is_dir($pathMnemosyne)) {
    @mkdir($pathMnemosyne, 0755, true);
} 

// Fichier de log quotidien unique : AAAAMMDD.log
$dailyLogFile = rtrim($pathMnemosyne, '/') . '/' . date('Ymd') . '.log';

/**
 * Journalisation centralisée dans Mnémosyne au format strict AubeZero
 * Format : AAAAMMDDHHMM-[PROGRAMME]-[INDICATEUR] - Message
 */
function logMnemosyne(string $filePath, string$indicator, string $message): void {$timestamp = date('YmdHi');
    $program   = 'ARGOS-HTTP';$logLine   = "{$timestamp}-[{$program}]-[{$indicator}] - {$message}" . PHP_EOL;
    file_put_contents($filePath,$logLine, FILE_APPEND | LOCK_EX);
}

// Log du début d'exécution
logMnemosyne($dailyLogFile, '👉', "Initialisation du contrôle de disponibilité pour {$url}");

/**
 * Test de la connectivité HTTP
 */
function checkHttp(string $url, int$timeout = 5): array {
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
    curl_close($ch);

    $isUp = ($httpCode >= 200 &&$httpCode < 400);
    return [$isUp, $httpCode,$errorMsg];
}

/**
 * Notification vers Webhook Discord (Hermes)
 */
function sendDiscordAlert(string $webhook, string$message): string {
    if (empty($webhook)) {
        return "Webhook non configuré (Mode local/Air-gap)";
    }

    $payload = json_encode(
        ["content" => mb_convert_encoding($message, 'UTF-8', 'UTF-8')],
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_INVALID_UTF8_SUBSTITUTE
    );

    $ch = curl_init($webhook);
    curl_setopt_array($ch, [
        CURLOPT_POST           => true,
        CURLOPT_POSTFIELDS     => $payload,
        CURLOPT_HTTPHEADER     => ["Content-Type: application/json; charset=utf-8"],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT        => 5,
        CURLOPT_SSL_VERIFYPEER => false,
    ]);

    $response  = curl_exec($ch);
    $httpCode  = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlError = curl_error($ch);
    curl_close($ch);

    if ($curlError) {
        return "ÉCHEC cURL : " . $curlError;
    }
    if ($httpCode < 200 || $httpCode >= 300) {
        return "ÉCHEC HTTP (Code {$httpCode}) : " . $response;
    }

    return "Succès Discord (Code {$httpCode})";
}

// --------------------------------------------------
// 2. ÉVALUATION DU SERVICE & HISTORIQUE DE STATUT
// --------------------------------------------------
list($isUp, $httpCode,$curlError) = checkHttp($url,$timeout);
$currentStatus =$isUp ? 'UP' : 'DOWN';

$previousStatus = 'UP';
if (file_exists($statusFile)) {
    $previousStatus = trim((string)file_get_contents($statusFile));
}

logMnemosyne($dailyLogFile, '=', "État précédent: {$previousStatus} | État actuel: {$currentStatus} (Code: {$httpCode})");

// --------------------------------------------------
// 3. GESTION DES CHANGEMENTS D'ÉTAT & NOTIFICATIONS
// --------------------------------------------------
if ($previousStatus === 'UP' && $currentStatus === 'DOWN') {$msg = "🚨 **ALERTE AUBEZERO // ARGOS**\nLe service `$url` est indisponible ! (HTTP Code: {$httpCode})";
    $result = sendDiscordAlert($webhook,$msg);
    logMnemosyne($dailyLogFile, '-', "Réseau indisponible. Notification : {$result}");

} elseif ($previousStatus === 'DOWN' && $currentStatus === 'UP') {$msg = "✅ **RÉTABLISSEMENT AUBEZERO // ARGOS**\nLe service `$url` répond à nouveau normalement. (HTTP Code: {$httpCode})";
    $result = sendDiscordAlert($webhook,$msg);
    logMnemosyne($dailyLogFile, '+', "Service de nouveau opérationnel. Notification : {$result}");

} else {
    logMnemosyne($dailyLogFile, '~', "Contrôle de routine terminé sans modification d'état.");
}

file_put_contents($statusFile,$currentStatus);
logMnemosyne($dailyLogFile, '✓', "Fin d'exécution nominale du contrôle Argos.");

// --------------------------------------------------
// 4. RENDU UI HUD MILITAIRE FUTURISTE (SI ACCÈS WEB)
// --------------------------------------------------
if (php_sapi_name() !== 'cli') {
    header('Content-Type: text/html; charset=utf-8');
    
    // Extrait les 50 dernières lignes de logs pour la modale
    $logsContent = "Aucun enregistrement aujourd'hui.";
    if (file_exists($dailyLogFile)) {
        $lines = file($dailyLogFile);
        $logsContent = implode("", array_slice($lines, -50));
    }
    ?>
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>AUBEZERO // ARGOS - SURVEILLANCE HTTP</title>
        <style>
            :root {
                --bg-primary: #050b14;
                --bg-card: #0a1728;
                --border-color: #00e5ff;
                --border-dim: #0056b3;
                --text-main: #d0f0ff;
                --text-bright: #00e5ff;
                --status-green: #00ff66;
                --status-red: #ff3333;
            }

            * {
                box-sizing: border-box;
                font-family: 'Consolas', 'Courier New', monospace;
            }

            body {
                background-color: var(--bg-primary);
                color: var(--text-main);
                margin: 0;
                padding: 20px;
                min-height: 100vh;
                background-image: 
                    radial-gradient(circle at 50% 50%, rgba(0, 229, 255, 0.05) 0%, transparent 80%),
                    linear-gradient(rgba(0, 229, 255, 0.03) 1px, transparent 1px),
                    linear-gradient(90deg, rgba(0, 229, 255, 0.03) 1px, transparent 1px);
                background-size: 100% 100%, 20px 20px, 20px 20px;
            }

            .container {
                max-width: 900px;
                margin: 0 auto;
            }

            header {
                display: flex;
                justify-content: space-between;
                align-items: center;
                border-bottom: 1px solid var(--border-dim);
                padding-bottom: 15px;
                margin-bottom: 25px;
            }

            h1 {
                margin: 0;
                font-size: 1.4rem;
                color: var(--text-bright);
                letter-spacing: 2px;
                text-transform: uppercase;
            }

            .hud-panel {
                background: var(--bg-card);
                border: 1px solid var(--border-dim);
                padding: 20px;
                position: relative;
                clip-path: polygon(0 0, calc(100% - 15px) 0, 100% 15px, 100% 100%, 15px 100%, 0 calc(100% - 15px));
                margin-bottom: 20px;
            }

            .status-badge {
                display: inline-block;
                padding: 6px 12px;
                font-weight: bold;
                border: 1px solid;
                text-transform: uppercase;
                letter-spacing: 1px;
            }

            .status-badge.up {
                border-color: var(--status-green);
                color: var(--status-green);
                background: rgba(0, 255, 102, 0.1);
            }

            .status-badge.down {
                border-color: var(--status-red);
                color: var(--status-red);
                background: rgba(255, 51, 51, 0.1);
            }

            .btn-hud {
                padding: 10px 20px;
                background: transparent;
                border: 1px solid var(--border-color);
                color: var(--text-bright);
                font-weight: bold;
                letter-spacing: 1px;
                text-transform: uppercase;
                cursor: pointer;
                transition: all 0.2s ease;
            }

            .btn-hud:hover {
                background: var(--border-color);
                color: #000;
                box-shadow: 0 0 10px rgba(0, 229, 255, 0.5);
            }

            /* --- MODALE TACTIQUE --- */
            .modal-overlay {
                display: none;
                position: fixed;
                top: 0; left: 0; width: 100%; height: 100%;
                background: rgba(2, 6, 12, 0.85);
                backdrop-filter: blur(5px);
                justify-content: center;
                align-items: center;
                z-index: 1000;
            }

            .modal-overlay.active {
                display: flex;
            }

            .modal-card {
                background: var(--bg-card);
                border: 1px solid var(--border-color);
                box-shadow: 0 0 25px rgba(0, 229, 255, 0.25);
                width: 90%;
                max-width: 800px;
                padding: 25px;
                position: relative;
                clip-path: polygon(0 0, calc(100% - 15px) 0, 100% 15px, 100% 100%, 15px 100%, 0 calc(100% - 15px));
            }

            .modal-close {
                position: absolute;
                top: 15px;
                right: 15px;
                background: transparent;
                border: 1px solid var(--status-red);
                color: var(--status-red);
                padding: 4px 10px;
                cursor: pointer;
            }

            pre.log-viewer {
                background: #02060c;
                border: 1px solid var(--border-dim);
                padding: 15px;
                color: var(--text-bright);
                max-height: 400px;
                overflow-y: auto;
                font-size: 0.85rem;
                line-height: 1.4;
            }

            /* --- TOAST DISCORD --- */
            .toast-container {
                position: fixed;
                bottom: 20px;
                right: 20px;
                z-index: 9999;
            }

            .toast-discord {
                background: #18191c;
                border-left: 4px solid var(--status-red);
                color: #dcddde;
                padding: 12px 18px;
                border-radius: 4px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.5);
                display: flex;
                align-items: center;
                gap: 12px;
                font-size: 0.85rem;
            }
        </style>
    </head>
    <body>

        <div class="toast-container" id="toastContainer"></div>

        <div class="container">
            <header>
                <h1>ARGOS // SURVEILLANCE SYSTEME</h1>
                <span style="font-size: 0.8rem; color: var(--border-color);">PROJET AUBEZERO</span>
            </header>

            <div class="hud-panel">
                <h3 style="margin-top:0; color: var(--text-bright);">CIBLE : <?= htmlspecialchars($url) ?></h3>
                <p>Statut Réseau : 
                    <span class="status-badge <?= strtolower($currentStatus) ?>">
                        <?= $currentStatus ?> (CODE HTTP <?= $httpCode ?>)
                    </span>
                </p>
                <button class="btn-hud" onclick="openLogModal()">CONSULTER LOGS MNÉMOSYNE</button>
            </div>
        </div>

        <!-- FENÊTRE MODALE -->
        <div id="logModal" class="modal-overlay">
            <div class="modal-card">
                <button class="modal-close" onclick="closeLogModal()">[X] FERMER</button>
                <h3 style="color: var(--text-bright); margin-top: 0;">JOURNAL D'ÉVÉNEMENTS (MNÉMOSYNE)</h3>
                <pre class="log-viewer"><?= htmlspecialchars($logsContent) ?></pre>
            </div>
        </div>

        <script>
            function openLogModal() {
                document.getElementById('logModal').classList.add('active');
            }

            function closeLogModal() {
                document.getElementById('logModal').classList.remove('active');
            }

            function showToast(message) {
                const container = document.getElementById('toastContainer');
                const toast = document.createElement('div');
                toast.className = 'toast-discord';
                toast.innerHTML = `<div><strong>Alerte Système :</strong> ${message}</div>`;
                container.appendChild(toast);
                setTimeout(() => toast.remove(), 4000);
            }

            <?php if ($currentStatus === 'DOWN'): ?>
                showToast("Échec de connexion au service <?= htmlspecialchars($url) ?> (Code HTTP: <?=$httpCode ?>)");
            <?php endif; ?>
        </script>
    </body>
    </html>
    <?php
}
