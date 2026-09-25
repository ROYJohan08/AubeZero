<?php
session_start();

// --- CHARGEMENT DU MOT DE PASSE PAR DÉFAUT VIA CREDENTIALS.ENV ---
$envFile = '/etc/AubeZero/Cerbere/credentials.env';
if (!file_exists($envFile)) {
    $envFile = __DIR__ . '/credentials.env';
}
$config = file_exists($envFile) ? parse_ini_file($envFile) : [];

// Clé par défaut issue du .env ou fallback
$defaultPassword = $config['PASSWORD_HIGH'] ?? ($config['TARGET_PASSWORD'] ?? '');

/**
 * Chiffre une chaîne de texte (latitude ou longitude) en AES-256-CBC
 * Compatible avec le déchiffrement WebCrypto (protocoles.php)
 */
function encryptGps(string $data, string $password): string {
    if (empty($data) || empty($password)) {
        return '';
    }
    
    $cipher = "aes-256-cbc";
    $key = hash('sha256', $password, true);
    $ivLength = openssl_cipher_iv_length($cipher);
    $iv = openssl_random_pseudo_bytes($ivLength);
    $encryptedRaw = openssl_encrypt($data, $cipher, $key, OPENSSL_RAW_DATA, $iv);
    
    return base64_encode($iv . $encryptedRaw);
}

// --- TRAITEMENT SI EXÉCUTÉ EN LIGNE DE COMMANDES (CLI) ---
if (php_sapi_name() === 'cli') {
    echo "=== [ARGOS] Outil de Chiffrement GPS ===\n";
    $lat = readline("Latitude : ");
    $lng = readline("Longitude : ");
    $pass = readline("Mot de passe client : ");
    
    if (empty($pass)) $pass = $defaultPassword;
    
    echo "\nRésultats chiffrés :\n";
    echo "lat : " . encryptGps($lat, $pass) . "\n";
    echo "lng : " . encryptGps($lng, $pass) . "\n";
    exit;
}

// --- TRAITEMENT DU FORMULAIRE WEB ---
$resultLat = '';
$resultLng = '';
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $lat = trim($_POST['latitude'] ?? '');
    $lng = trim($_POST['longitude'] ?? '');
    $password = trim($_POST['password'] ?? '');

    if (empty($lat) || empty($lng) || empty($password)) {
        $error = "ANOMALIE : Saisie incomplète. Tous les champs tactiques sont requis.";
    } else {
        $resultLat = encryptGps($lat, $password);
        $resultLng = encryptGps($lng, $password);
    }
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AubeZero // ARGOS - Chiffrement GPS</title>
    <style>
        :root {
            --bg-primary: #050b14;
            --bg-card: #0a1728;
            --border-color: #00e5ff;
            --border-dim: #0056b3;
            --text-main: #d0f0ff;
            --text-bright: #00e5ff;
            --accent-blue: #0077ff;
            --toast-red: #ff3333;
            --success-green: #00ff66;
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
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            background-image: 
                radial-gradient(circle at 50% 50%, rgba(0, 229, 255, 0.05) 0%, transparent 80%),
                linear-gradient(rgba(0, 229, 255, 0.03) 1px, transparent 1px),
                linear-gradient(90deg, rgba(0, 229, 255, 0.03) 1px, transparent 1px);
            background-size: 100% 100%, 20px 20px, 20px 20px;
        }

        .hud-card {
            width: 100%;
            max-width: 520px;
            background: var(--bg-card);
            border: 1px solid var(--border-dim);
            box-shadow: 0 0 15px rgba(0, 229, 255, 0.15);
            padding: 30px;
            position: relative;
            clip-path: polygon(0 0, calc(100% - 15px) 0, 100% 15px, 100% 100%, 15px 100%, 0 calc(100% - 15px));
        }

        .hud-card::before {
            content: "ARGOS // AZGps";
            position: absolute;
            top: 0;
            left: 0;
            background: var(--border-dim);
            color: #000;
            font-size: 10px;
            font-weight: bold;
            padding: 2px 8px;
            letter-spacing: 1px;
        }

        .hud-header {
            border-bottom: 1px solid var(--border-dim);
            padding-bottom: 10px;
            margin-bottom: 25px;
            margin-top: 10px;
        }

        h2 {
            margin: 0;
            color: var(--text-bright);
            font-size: 1.2rem;
            text-transform: uppercase;
            letter-spacing: 2px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        h2::before {
            content: "►";
            font-size: 0.9rem;
            color: var(--border-color);
        }

        .form-group {
            margin-bottom: 20px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-size: 0.85rem;
            color: var(--text-bright);
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        input[type="text"], input[type="password"] {
            width: 100%;
            padding: 12px;
            background: rgba(0, 20, 40, 0.8);
            border: 1px solid var(--border-dim);
            color: #fff;
            font-size: 0.95rem;
            outline: none;
            transition: border-color 0.3s, box-shadow 0.3s;
        }

        input[type="text"]:focus, input[type="password"]:focus {
            border-color: var(--border-color);
            box-shadow: 0 0 8px rgba(0, 229, 255, 0.4);
        }

        .btn-hud {
            width: 100%;
            padding: 14px;
            background: transparent;
            border: 1px solid var(--border-color);
            color: var(--text-bright);
            font-weight: bold;
            text-transform: uppercase;
            letter-spacing: 2px;
            cursor: pointer;
            transition: all 0.2s ease;
            position: relative;
            margin-top: 10px;
        }

        .btn-hud:hover {
            background: var(--border-color);
            color: #000;
            box-shadow: 0 0 15px rgba(0, 229, 255, 0.5);
        }

        /* --- TOAST DISCORD STYLE --- */
        .toast-container {
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 9999;
        }

        .toast-discord {
            background: #18191c;
            border-left: 4px solid var(--toast-red);
            color: #dcddde;
            padding: 12px 18px;
            border-radius: 4px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.5);
            display: flex;
            align-items: center;
            gap: 12px;
            min-width: 280px;
            animation: slideIn 0.3s ease-out;
            font-size: 0.85rem;
        }

        .toast-discord .toast-title {
            color: #ffffff;
            font-weight: bold;
            margin-bottom: 2px;
        }

        @keyframes slideIn {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }

        /* --- MODALE HUD --- */
        .modal-overlay {
            display: flex;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(2, 6, 12, 0.85);
            backdrop-filter: blur(4px);
            justify-content: center;
            align-items: center;
            z-index: 1000;
        }

        .modal-content {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            box-shadow: 0 0 25px rgba(0, 229, 255, 0.3);
            width: 90%;
            max-width: 550px;
            padding: 25px;
            clip-path: polygon(0 0, calc(100% - 15px) 0, 100% 15px, 100% 100%, 15px 100%, 0 calc(100% - 15px));
        }

        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid var(--border-dim);
            padding-bottom: 10px;
            margin-bottom: 15px;
        }

        .modal-header h3 {
            margin: 0;
            color: var(--success-green);
            font-size: 1rem;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .modal-body code {
            display: block;
            background: rgba(0, 0, 0, 0.6);
            border: 1px solid var(--border-dim);
            color: var(--text-bright);
            padding: 10px;
            margin: 8px 0 15px 0;
            word-break: break-all;
            font-size: 0.85rem;
        }

        .btn-close {
            background: transparent;
            border: 1px solid var(--toast-red);
            color: var(--toast-red);
            padding: 8px 16px;
            cursor: pointer;
            float: right;
            text-transform: uppercase;
            font-size: 0.8rem;
        }

        .btn-close:hover {
            background: var(--toast-red);
            color: #fff;
        }
    </style>
</head>
<body>

    <!-- DEBUT DE L'INTERFACE PRINCIPALE HUD -->
    <div class="hud-card">
        <div class="hud-header">
            <h2>Générateur GPS Chiffré</h2>
        </div>

        <form method="POST">
            <div class="form-group">
                <label for="latitude">Coordonnée Latitude :</label>
                <input type="text" id="latitude" name="latitude" placeholder="ex: 48.856614" value="<?= htmlspecialchars($_POST['latitude'] ?? '') ?>" autocomplete="off" required>
            </div>
            
            <div class="form-group">
                <label for="longitude">Coordonnée Longitude :</label>
                <input type="text" id="longitude" name="longitude" placeholder="ex: 2.352221" value="<?= htmlspecialchars($_POST['longitude'] ?? '') ?>" autocomplete="off" required>
            </div>
            
            <div class="form-group">
                <label for="password">Clé de Chiffrement :</label>
                <input type="password" id="password" name="password" value="<?= htmlspecialchars($_POST['password'] ?? $defaultPassword) ?>" required>
            </div>

            <button type="submit" class="btn-hud">Exécuter le chiffrement</button>
        </form>
    </div>

    <!-- TOAST ERREUR DISCORD -->
    <?php if (!empty($error)): ?>
        <div class="toast-container">
            <div class="toast-discord">
                <div>
                    <div class="toast-title">Alerte Système</div>
                    <div><?= htmlspecialchars($error) ?></div>
                </div>
            </div>
        </div>
    <?php endif; ?>

    <!-- MODALE TACTIQUE DE RÉSULTAT -->
    <?php if ($resultLat && $resultLng): ?>
        <div class="modal-overlay" id="resultModal">
            <div class="modal-content">
                <div class="modal-header">
                    <h3>[✓] Traitement Chiffrement Réussi</h3>
                </div>
                <div class="modal-body">
                    <p style="font-size: 0.85rem; color: #aaa; margin-top:0;">Données prêtes pour insertion dans <code>protocoles_data.json</code> :</p>
                    
                    <label>"lat":</label>
                    <code><?= htmlspecialchars($resultLat) ?></code>
                    
                    <label>"lng":</label>
                    <code><?= htmlspecialchars($resultLng) ?></code>
                    
                    <button type="button" class="btn-close" onclick="document.getElementById('resultModal').style.display='none'">Fermer</button>
                </div>
            </div>
        </div>
    <?php endif; ?>

</body>
</html>
