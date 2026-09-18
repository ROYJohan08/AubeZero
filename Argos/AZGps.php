<?php
session_start();

// --- CHARGEMENT DU MOT DE PASSE PAR DÉFAUT VIA CREDENTIALS.ENV ---
$envFile = __DIR__ . '/credentials.env';
$config  = file_exists($envFile) ? parse_ini_file($envFile) : [];

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
    // Génération d'une clé de 256 bits (32 octets) via SHA-256 du mot de passe
    $key = hash('sha256', $password, true);
    
    // Génération d'un IV aléatoire de 16 octets
    $ivLength = openssl_cipher_iv_length($cipher);
    $iv = openssl_random_pseudo_bytes($ivLength);
    
    // Chiffrement avec OPENSSL_RAW_DATA (Renvoie du binaire brut, pas du base64)
    $encryptedRaw = openssl_encrypt($data, $cipher, $key, OPENSSL_RAW_DATA, $iv);
    
    // Concaténation [IV binaire (16 octets)] + [Ciphertext binaire] puis encodage Base64 UNIQUE
    return base64_encode($iv . $encryptedRaw);
}

// --- TRAITEMENT SI EXÉCUTÉ EN LIGNE DE COMMANDES (CLI) ---
if (php_sapi_name() === 'cli') {
    echo "=== Outil de Chiffrement GPS ===\n";
    $lat = readline("Latitude : ");
    $lng = readline("Longitude : ");
    $pass = readline("Mot de passe client : ");
    
    if (empty($pass)) $pass = $defaultPassword;
    
    echo "\nResultats chiffrés :\n";
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
        $error = "Veuillez remplir tous les champs (Latitude, Longitude et Mot de passe).";
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
    <title>Générateur de Coordonnées GPS Chiffrées</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #121212; color: #e0e0e0; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 40px auto; background: #1e1e1e; padding: 25px; border-radius: 8px; border: 1px solid #333; }
        h2 { margin-top: 0; color: #fff; }
        .form-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input[type="text"], input[type="password"] { width: 100%; padding: 10px; background: #2b2b2b; border: 1px solid #444; color: #fff; border-radius: 4px; box-sizing: border-box; }
        .btn { width: 100%; padding: 12px; background: #007bff; border: none; color: #fff; font-weight: bold; border-radius: 4px; cursor: pointer; margin-top: 10px; }
        .btn:hover { background: #0056b3; }
        .result-box { background: #181818; padding: 15px; border-radius: 6px; border: 1px solid #28a745; margin-top: 20px; word-break: break-all; }
        .result-box code { color: #28a745; font-family: monospace; display: block; margin-top: 5px; }
        .error { color: #dc3545; font-weight: bold; margin-bottom: 15px; }
    </style>
</head>
<body>
    <div class="container">
        <h2>Chiffrer des coordonnées GPS</h2>
        
        <?php if (!empty($error)): ?>
            <div class="error"><?= htmlspecialchars($error) ?></div>
        <?php endif; ?>

        <form method="POST">
            <div class="form-group">
                <label for="latitude">Latitude :</label>
                <input type="text" id="latitude" name="latitude" placeholder="ex: 48.856614" value="<?= htmlspecialchars($_POST['latitude'] ?? '') ?>" required>
            </div>
            
            <div class="form-group">
                <label for="longitude">Longitude :</label>
                <input type="text" id="longitude" name="longitude" placeholder="ex: 2.352221" value="<?= htmlspecialchars($_POST['longitude'] ?? '') ?>" required>
            </div>
            
            <div class="form-group">
                <label for="password">Mot de passe de chiffrement :</label>
                <input type="password" id="password" name="password" value="<?= htmlspecialchars($_POST['password'] ?? $defaultPassword) ?>" required>
            </div>

            <button type="submit" class="btn">Chiffrer les coordonnées</button>
        </form>

        <?php if ($resultLat && $resultLng): ?>
            <div class="result-box">
                <h4>Résultats à copier dans votre <code>protocoles_data.json</code> :</h4>
                <p><strong>"lat":</strong> <code><?= htmlspecialchars($resultLat) ?></code></p>
                <p><strong>"lng":</strong> <code><?= htmlspecialchars($resultLng) ?></code></p>
            </div>
        <?php endif; ?>
    </div>
</body>
</html>
