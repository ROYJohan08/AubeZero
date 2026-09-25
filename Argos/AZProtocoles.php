<?php
session_start();

// --- CHARGEMENT DE LA CONFIGURATION ---
$envFile = '/etc/AubeZero/Cerbere/credentials.env';
if (!file_exists($envFile)) {$envFile = __DIR__ . '/credentials.env';
}
$config = file_exists($envFile) ? parse_ini_file($envFile) : [];

$stateFilePath      = '/home/lelabdurhg/api/scenarios_state.json';$protocolesDataFile = '/home/lelabdurhg/api/protocoles_data.json';

$debugLogs = [];$debugLogs[] = "--- DÉBUT DE L'EXÉCUTION (protocoles.php) ---";
$debugLogs[] = "PHP Version : " . phpversion();

// --- PARSER MARKDOWN SIMPLE ---
function parseMarkdown($text, &$debugLogs) {
    if (empty($text)) {$debugLogs[] = "parseMarkdown() : Texte vide reçu.";
        return '';
    }
    $debugLogs[] = "parseMarkdown() : Traitement du texte (" . strlen($text) . " caractères).";
    
    $text = preg_replace('/^### (.*$)/im', '<h3>$1</h3>',$text);
    $text = preg_replace('/^## (.*$)/im', '<h2>$1</h2>',$text);
    $text = preg_replace('/^# (.*$)/im', '<h1>$1</h1>', $text);$text = preg_replace('/\*\*(.*?)\*\*/s', '<strong>$1</strong>', $text);$text = preg_replace('/\*([^\*]+)\*/s', '<em>$1</em>',$text);
    $text = preg_replace('/^\* (.*$)/im', '<li>$1</li>',$text);
    
    return nl2br($text);
}

// --- CHARGEMENT DES FICHIERS ---
function getStates($filePath, &$debugLogs) {$debugLogs[] = "Vérification du fichier d'état : " . $filePath;
    if (!file_exists($filePath)) {$debugLogs[] = "-> ERREUR : Le fichier d'état n'existe pas.";
        return [];
    }
    
    $content = file_get_contents($filePath);
    if ($content === false) {$debugLogs[] = "-> ERREUR : Lecture du fichier d'état impossible.";
        return [];
    }
    
    $data = json_decode($content, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        $debugLogs[] = "-> ERREUR JSON état : " . json_last_error_msg();
        return [];
    }
    return $data ?? [];
}

function getProtocolesData($filePath, &$debugLogs) {$debugLogs[] = "Lecture du fichier protocoles_data.json : " . $filePath;

    if (!file_exists($filePath) || filesize($filePath) === 0) {$debugLogs[] = "-> ERREUR : Le fichier protocoles_data.json est introuvable ou vide.";
        return [];
    }

    $content = file_get_contents($filePath);
    $data = json_decode($content, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        $debugLogs[] = "-> ERREUR JSON protocoles : " . json_last_error_msg();
        return [];
    }

    return $data ?? [];
}

$states = getStates($stateFilePath,$debugLogs);
$allProtocoles = getProtocolesData($protocolesDataFile, $debugLogs);$activeProtocoles = [];

// Filtrage des protocoles actifs
if (empty($states)) {$debugLogs[] = "-> \$states est vide. Activation de tous les protocoles.";
    foreach ($allProtocoles as$key => $proto) {$proto['description_html'] = parseMarkdown($proto['description'] ?? '',$debugLogs);
        
        if (!empty($proto['points'])) {
            foreach ($proto['points'] as$idx => $pt) {$debugLogs[] = "GPS Brut [{$key}] Pt " . ($idx + 1) . " -> Lat: " . ($pt['lat'] ?? 'N/A') . " \vert{} Lng: " . ($pt['lng'] ?? 'N/A');
            }
        }
        
        $activeProtocoles[$key] =$proto;
    }
} else {
    foreach ($allProtocoles as$key => $proto) {$stringKey = strtoupper(trim((string)$key));$isMatch = false;

        foreach ($states as $stateKey =>$stateVal) {
            $cleanStateKey = strtoupper(trim($stateKey));
            $cleanStateVal = strtoupper(trim((string)$stateVal));

            if ($cleanStateVal === 'ON' &&$stringKey === $cleanStateKey) {$isMatch = true;
                break;
            }
        }

        if ($isMatch) {$proto['description_html'] = parseMarkdown($proto['description'] ?? '',$debugLogs);
            
            if (!empty($proto['points'])) {
                foreach ($proto['points'] as$idx => $pt) {$debugLogs[] = "GPS Brut [{$key}] Pt " . ($idx + 1) . " -> Lat: " . ($pt['lat'] ?? 'N/A') . " \vert{} Lng: " . ($pt['lng'] ?? 'N/A');
                }
            }
            
            $activeProtocoles[$key] =$proto;
        }
    }
}

$debugLogs[] = "Nombre de protocoles actifs : " . count($activeProtocoles);

// Export API JSON
if (isset($_GET['format']) &&$_GET['format'] === 'json') {
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($activeProtocoles, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    exit;
}
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AubeZero // Protocoles d'Extraction</title>
    <style>
        :root {
            --bg-primary: #050b14;
            --bg-card: #0a1728;
            --border-color: #00e5ff;
            --border-dim: #0056b3;
            --text-main: #d0f0ff;
            --text-bright: #00e5ff;
            --toast-red: #ff3333;
            --success-green: #00ff66;
            --warning-amber: #ffc107;
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
            max-width: 1100px;
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
            font-size: 1.5rem;
            color: var(--text-bright);
            text-transform: uppercase;
            letter-spacing: 2px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        h1::before {
            content: "►";
            font-size: 1rem;
            color: var(--border-color);
        }

        .btn-hud {
            padding: 8px 16px;
            background: transparent;
            border: 1px solid var(--border-color);
            color: var(--text-bright);
            font-weight: bold;
            text-transform: uppercase;
            letter-spacing: 1px;
            text-decoration: none;
            cursor: pointer;
            transition: all 0.2s ease;
            display: inline-block;
            font-size: 0.85rem;
        }

        .btn-hud:hover {
            background: var(--border-color);
            color: #000;
            box-shadow: 0 0 10px rgba(0, 229, 255, 0.5);
        }

        .section {
            background: var(--bg-card);
            padding: 25px;
            border: 1px solid var(--border-dim);
            position: relative;
            clip-path: polygon(0 0, calc(100% - 15px) 0, 100% 15px, 100% 100%, 15px 100%, 0 calc(100% - 15px));
        }

        .section-title {
            margin-top: 0;
            color: var(--text-bright);
            font-size: 1.1rem;
            letter-spacing: 1px;
            text-transform: uppercase;
            border-bottom: 1px dashed var(--border-dim);
            padding-bottom: 8px;
            margin-bottom: 20px;
        }

        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
        }

        .card {
            background: rgba(0, 20, 40, 0.6);
            border: 1px solid var(--border-dim);
            padding: 20px;
            cursor: pointer;
            transition: all 0.2s ease;
            position: relative;
        }

        .card:hover {
            border-color: var(--border-color);
            box-shadow: 0 0 12px rgba(0, 229, 255, 0.3);
            transform: translateY(-2px);
        }

        .card h3 {
            margin-top: 0;
            font-size: 1.1rem;
            letter-spacing: 1px;
            text-transform: uppercase;
        }

        .card-click-hint {
            font-size: 0.75rem;
            color: var(--text-bright);
            margin-top: 15px;
            text-transform: uppercase;
            letter-spacing: 1px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        /* --- FENÊTRES MODALES --- */
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
            max-width: 700px;
            padding: 25px;
            position: relative;
            max-height: 85vh;
            overflow-y: auto;
            clip-path: polygon(0 0, calc(100% - 15px) 0, 100% 15px, 100% 100%, 15px 100%, 0 calc(100% - 15px));
        }

        .modal-close {
            position: absolute;
            top: 15px;
            right: 15px;
            background: transparent;
            border: 1px solid var(--toast-red);
            color: var(--toast-red);
            padding: 4px 10px;
            cursor: pointer;
            font-size: 0.9rem;
            font-weight: bold;
        }

        .modal-close:hover {
            background: var(--toast-red);
            color: #fff;
        }

        .markdown-body {
            background: rgba(0, 10, 20, 0.8);
            padding: 15px;
            border: 1px solid var(--border-dim);
            margin: 15px 0;
            line-height: 1.5;
            font-size: 0.9rem;
        }

        .gps-step-box {
            background: rgba(0, 15, 30, 0.9);
            padding: 15px;
            border: 1px solid var(--border-dim);
            margin-top: 15px;
        }

        .password-form {
            display: flex;
            gap: 10px;
            margin: 10px 0;
        }

        .input-key {
            flex: 1;
            padding: 10px;
            background: rgba(0, 20, 40, 0.8);
            border: 1px solid var(--border-dim);
            color: #fff;
            outline: none;
            font-size: 0.9rem;
        }

        .input-key:focus {
            border-color: var(--border-color);
        }

        /* --- TOASTS DISCORD --- */
        .toast-container {
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 9999;
            display: flex;
            flex-direction: column;
            gap: 10px;
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

        .toast-discord.warning {
            border-left-color: var(--warning-amber);
        }

        .toast-discord.success {
            border-left-color: var(--success-green);
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

        /* Console Debug HUD */
        .client-debug-box {
            background: #02060c;
            border: 1px solid var(--border-dim);
            padding: 10px;
            margin-top: 15px;
            font-size: 0.8rem;
            color: var(--text-bright);
            max-height: 120px;
            overflow-y: auto;
        }

        .client-debug-title {
            font-weight: bold;
            border-bottom: 1px dashed var(--border-dim);
            padding-bottom: 4px;
            margin-bottom: 6px;
            color: var(--warning-amber);
        }

        .debug-console {
            background: #02060c;
            border: 1px solid var(--warning-amber);
            margin-top: 20px;
            padding: 15px;
        }

        .debug-console h3 {
            color: var(--warning-amber);
            margin-top: 0;
            font-size: 0.95rem;
        }

        .debug-log {
            color: #aaa;
            margin: 4px 0;
            font-size: 0.8rem;
            white-space: pre-wrap;
            word-break: break-all;
        }
    </style>
</head>
<body>

    <div class="toast-container" id="toastContainer"></div>

    <div class="container">
        <header>
            <h1>MODULE // PROTOCOLES D'EXTRACTION</h1>
            <div>
                <a href="?format=json" target="_blank" class="btn-hud">Export JSON</a>
            </div>
        </header>

        <div class="section">
            <div class="section-title">Protocoles Activés (<?= count($activeProtocoles) ?>)</div>
            <?php if (empty($activeProtocoles)): ?>
                <p style="color: #888;">Aucun protocole d'extraction n'est actuellement actif sur le réseau.</p>
            <?php else: ?>
                <div class="grid">
                    <?php foreach ($activeProtocoles as $code =>$proto): ?>
                        <div class="card" style="border-left: 4px solid <?= htmlspecialchars($proto['couleur'] ?? '#00e5ff') ?>;" onclick="openProtocolModal('<?= htmlspecialchars($code) ?>')">
                            <h3 style="color: <?= htmlspecialchars($proto['couleur'] ?? '#00e5ff') ?>;">[<?= htmlspecialchars($code) ?>] <?= htmlspecialchars($proto['nom'] ?? 'Sans Nom') ?></h3>
                            <p style="font-size: 0.85rem; color: #aaa;">Sélectionner pour initialiser le déchiffrement et le guidage d'itinéraire.</p>
                            <div class="card-click-hint">ACCÉDER AU PROTOCOLE <span>►</span></div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </div>

        <?php if (isset($_GET['debug'])): ?>
        <div class="debug-console">
            <h3>CONSOLE DE DÉBOGAGE SERVEUR (protocoles.php)</h3>
            <?php foreach ($debugLogs as $index =>$log): ?>
                <div class="debug-log">[<?= $index ?>] > <?= htmlspecialchars($log) ?></div>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>
    </div>

    <!-- MODALE TACTIQUE DE PROTOCOLE -->
    <div id="protocolModal" class="modal-overlay">
        <div class="modal-card">
            <button class="modal-close" onclick="closeProtocolModal()">[X] FERMER</button>
            <h2 id="modalTitle" style="margin-top:0; font-size: 1.2rem; text-transform: uppercase;">Titre du protocole</h2>
            
            <div class="markdown-body" id="modalMarkdown"></div>

            <!-- MODULE GPS PAS À PAS -->
            <div class="gps-step-box">
                <h4 style="margin-top:0; color: var(--text-bright); text-transform: uppercase; font-size: 0.9rem;">Séquence de Navigation GPS</h4>
                <label for="clientPassword" style="font-size: 0.8rem; color: #aaa;">Clé Client de Déchiffrement :</label>
                <div class="password-form">
                    <input type="password" id="clientPassword" class="input-key" placeholder="Saisir la clé tactique..." onkeydown="handleKeyPress(event)">
                    <button type="button" class="btn-hud" onclick="updateGpsUI()">Déchiffrer</button>
                </div>
                
                <div id="gpsStepInfo" style="font-size: 0.85rem; margin-top: 10px;">Saisissez votre clé pour débloquer les coordonnées.</div>
                
                <div class="client-debug-box">
                    <div class="client-debug-title">&gt;_ Tracé de Déchiffrement Temps Réel</div>
                    <div id="clientDebugLog">Attente d'une clé d'accès...</div>
                </div>

                <button id="btnCheckGps" class="btn-hud" style="display:none; width: 100%; margin-top: 15px;" onclick="checkUserLocation()">Démarrer le suivi GPS en temps réel</button>
                <div id="mapsLinkBox" style="margin-top: 12px; font-size: 0.85rem;"></div>
            </div>
        </div>
    </div>

    <script>
        const protocolesData = <?= json_encode($activeProtocoles, JSON_UNESCAPED_UNICODE) ?>;
        let currentProtoCode = null;
        let currentPointIndex = 0;
        let decryptedCoords = null;
        let geoWatchId = null;

        function showToast(message, title = "Alerte Système", type = "error") {
            const container = document.getElementById('toastContainer');
            const toast = document.createElement('div');
            toast.className = `toast-discord ${type}`;
            toast.innerHTML = `
                <div>
                    <div class="toast-title">${title}</div>
                    <div>${message}</div>
                </div>
            `;
            container.appendChild(toast);
            setTimeout(() => toast.remove(), 4000);
        }

        function logClientDebug(message, clear = false) {
            const container = document.getElementById('clientDebugLog');
            if (clear && container) container.innerHTML = '';
            if (container) {
                const time = new Date().toLocaleTimeString();
                container.innerHTML += `<div>[${time}] ${message}</div>`;
                container.scrollTop = container.scrollHeight;
            }
        }

        function openProtocolModal(code) {
            currentProtoCode = code;
            currentPointIndex = 0;
            decryptedCoords = null;
            const proto = protocolesData[code];

            if (!proto) return;

            document.getElementById('modalTitle').innerText = '[' + code + '] ' + (proto.nom || '');
            document.getElementById('modalTitle').style.color = proto.couleur || '#00e5ff';
            document.getElementById('modalMarkdown').innerHTML = proto.description_html || '';

            document.getElementById('clientPassword').value = '';
            logClientDebug("Modal activée pour le protocole : " + code, true);
            
            stopGeoTracking();
            updateGpsUI();
            document.getElementById('protocolModal').classList.add('active');
        }

        function closeProtocolModal() {
            stopGeoTracking();
            document.getElementById('protocolModal').classList.remove('active');
        }

        function handleKeyPress(e) {
            if (e.key === "Enter") {
                e.preventDefault();
                updateGpsUI();
            }
        }

        async function decryptAESCBC(encryptedBase64, password, coordName) {
            try {
                logClientDebug(`Déchiffrement (${coordName}) : "${encryptedBase64.substring(0, 15)}..."`);
                const rawData = Uint8Array.from(atob(encryptedBase64), c => c.charCodeAt(0));
                
                if (rawData.length < 17) {
                    logClientDebug(`&rarr; [ÉCHEC ${coordName}] Taille de données insuffisante.`);
                    return null;
                }

                const iv = rawData.slice(0, 16);
                const cipherText = rawData.slice(16);

                const enc = new TextEncoder();
                const keyMaterial = await window.crypto.subtle.digest('SHA-256', enc.encode(password));
                const key = await window.crypto.subtle.importKey(
                    "raw", keyMaterial, { name: "AES-CBC" }, false, ["decrypt"]
                );

                const decrypted = await window.crypto.subtle.decrypt(
                    { name: "AES-CBC", iv: iv }, key, cipherText
                );

                const resultStr = new TextDecoder().decode(decrypted);
                logClientDebug(`&rarr; [SUCCÈS ${coordName}] Valeur : ${resultStr}`);
                return resultStr;
            } catch (e) {
                logClientDebug(`&rarr; [ÉCHEC ${coordName}] WebCrypto : ${e.message}`);
                return null;
            }
        }

        async function updateGpsUI() {
            logClientDebug("--- Traitement des points de navigation ---", true);
            const proto = protocolesData[currentProtoCode];
            const points = proto.points || [];
            const password = document.getElementById('clientPassword').value;

            if (points.length === 0) {
                logClientDebug("Aucun point GPS associé.");
                document.getElementById('gpsStepInfo').innerText = "Aucune coordonnée GPS renseignée pour ce protocole.";
                document.getElementById('btnCheckGps').style.display = 'none';
                document.getElementById('mapsLinkBox').innerHTML = '';
                stopGeoTracking();
                return;
            }

            const targetPoint = points[currentPointIndex];
            logClientDebug(`Traitement Cible : Point ${currentPointIndex + 1}/${points.length}`);

            if (!password) {
                document.getElementById('gpsStepInfo').innerText = "Saisissez la clé client pour déchiffrer l'étape.";
                document.getElementById('btnCheckGps').style.display = 'none';
                document.getElementById('mapsLinkBox').innerHTML = '';
                stopGeoTracking();
                return;
            }

            let lat = targetPoint.lat;
            let lng = targetPoint.lng;

            if (typeof lat === 'string' && isNaN(lat)) {
                lat = await decryptAESCBC(lat, password, "LAT");
            }
            if (typeof lng === 'string' && isNaN(lng)) {
                lng = await decryptAESCBC(lng, password, "LNG");
            }

            if (!lat || !lng || isNaN(lat) || isNaN(lng)) {
                logClientDebug("Échec du déchiffrement.");
                document.getElementById('gpsStepInfo').innerText = "Clé invalide ou données altérées.";
                document.getElementById('btnCheckGps').style.display = 'none';
                document.getElementById('mapsLinkBox').innerHTML = '';
                showToast("Clé de déchiffrement invalide ou corrompue.", "Erreur Clé", "error");
                stopGeoTracking();
                return;
            }

            decryptedCoords = { lat: parseFloat(lat), lng: parseFloat(lng) };
            logClientDebug(`Coordonnées déchiffrées : (${decryptedCoords.lat}, ${decryptedCoords.lng})`);

            document.getElementById('btnCheckGps').style.display = 'block';
            document.getElementById('btnCheckGps').innerText = "DÉMARRER LE SUIVI GPS TEMPS RÉEL";
            document.getElementById('gpsStepInfo').innerHTML = `
                <strong style="color:var(--border-color);">Point ${currentPointIndex + 1} / ${points.length} :</strong> ${targetPoint.nom || 'Point ' + (currentPointIndex + 1)}<br>
                <strong>Cible déchiffrée :</strong> ${decryptedCoords.lat}, ${decryptedCoords.lng}
            `;
            
            document.getElementById('mapsLinkBox').innerHTML = `
                <a href="https://maps.google.com/?q=${decryptedCoords.lat},${decryptedCoords.lng}" target="_blank" style="color: var(--border-color);">► Ouvrir l'étape dans Google Maps</a>
            `;
        }

        function calculateDistanceInKm(lat1, lon1, lat2, lon2) {
            const R = 6371;
            const dLat = (lat2 - lat1) * Math.PI / 180;
            const dLon = (lon2 - lon1) * Math.PI / 180;
            const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
                      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
                      Math.sin(dLon/2) * Math.sin(dLon/2);
            return R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
        }

        function stopGeoTracking() {
            if (geoWatchId !== null) {
                navigator.geolocation.clearWatch(geoWatchId);
                geoWatchId = null;
                logClientDebug("Suivi GPS désactivé.");
            }
        }

        function checkUserLocation() {
            const proto = protocolesData[currentProtoCode];

            if (!navigator.geolocation) {
                showToast("Géolocalisation non supportée sur cet appareil.", "Erreur Matérielle", "error");
                return;
            }

            if (geoWatchId !== null) {
                stopGeoTracking();
                showToast("Suivi GPS suspendu.", "Info GPS", "warning");
                document.getElementById('btnCheckGps').innerText = "DÉMARRER LE SUIVI GPS TEMPS RÉEL";
                return;
            }

            showToast("Acquisition du signal GPS en cours...", "Suivi GPS", "success");
            document.getElementById('btnCheckGps').innerText = "ARRÊTER LE SUIVI GPS";

            geoWatchId = navigator.geolocation.watchPosition(
                (position) => {
                    const userLat = position.coords.latitude;
                    const userLng = position.coords.longitude;
                    const distance = calculateDistanceInKm(userLat, userLng, decryptedCoords.lat, decryptedCoords.lng);

                    logClientDebug(`Position : [${userLat.toFixed(5)}, ${userLng.toFixed(5)}] | Distance : ${distance.toFixed(3)} km`);

                    if (distance <= 1.0) {
                        stopGeoTracking();
                        
                        if (currentPointIndex + 1 < proto.points.length) {
                            showToast(`Point ${currentPointIndex + 1} atteint ! Passage à l'étape suivante...`, "Étape Validée", "success");
                            currentPointIndex++;
                            setTimeout(() => {
                                updateGpsUI();
                                checkUserLocation();
                            }, 2500);
                        } else {
                            showToast("Dernier point d'extraction atteint ! Protocole clôturé.", "Mission Terminée", "success");
                            document.getElementById('btnCheckGps').style.display = 'none';
                        }
                    } else {
                        logClientDebug(`En route vers le point ${currentPointIndex + 1} (${distance.toFixed(2)} km)`);
                    }
                },
                (err) => {
                    logClientDebug(`Erreur GPS : ${err.message}`);
                    showToast("Impossible d'accéder aux données GPS de l'appareil.", "Erreur GPS", "error");
                    stopGeoTracking();
                },
                {
                    enableHighAccuracy: true,
                    maximumAge: 5000,
                    timeout: 10000
                }
            );
        }

        document.addEventListener('keydown', function(e) {
            if (e.key === "Escape") closeProtocolModal();
        });
    </script>
</body>
</html>
