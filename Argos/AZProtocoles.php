<?php
session_start();

// --- CHARGEMENT DE LA CONFIGURATION ---
$envFile = __DIR__ . '/credentials.env';$config  = file_exists($envFile) ? parse_ini_file($envFile) : [];

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
    <title>Protocoles d'Extraction</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #121212; color: #e0e0e0; margin: 0; padding: 20px; }
        .container { max-width: 1000px; margin: 0 auto; }
        header { display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #333; padding-bottom: 15px; margin-bottom: 20px; }
        h1 { margin: 0; font-size: 1.8rem; color: #fff; }
        .btn { padding: 8px 16px; border-radius: 4px; text-decoration: none; font-size: 0.9rem; font-weight: bold; cursor: pointer; border: none; }
        .btn-json { background-color: #17a2b8; color: #fff; }
        .btn-submit { background-color: #007bff; color: #fff; padding: 10px 15px; border: none; border-radius: 4px; font-weight: bold; cursor: pointer; }
        .btn-submit:hover { background-color: #0056b3; }
        .section { background: #1e1e1e; padding: 20px; border-radius: 6px; margin-bottom: 20px; border: 1px solid #2d2d2d; }
        
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; margin-top: 15px; }
        .card { background: #252525; padding: 20px; border-radius: 6px; cursor: pointer; transition: transform 0.2s, box-shadow 0.2s; border-left: 6px solid #007bff; }
        .card:hover { transform: translateY(-3px); box-shadow: 0 5px 15px rgba(0,0,0,0.5); }
        .card h3 { margin-top: 0; font-size: 1.2rem; }
        .card-click-hint { font-size: 0.8rem; color: #888; margin-top: 15px; text-transform: uppercase; letter-spacing: 1px; }

        .modal-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0, 0, 0, 0.8); justify-content: center; align-items: center; z-index: 1000; }
        .modal-overlay.active { display: flex; }
        .modal-card { background: #222; border-radius: 8px; width: 90%; max-width: 650px; padding: 25px; position: relative; border: 1px solid #444; max-height: 85vh; overflow-y: auto; }
        .modal-close { position: absolute; top: 15px; right: 15px; background: none; border: none; color: #aaa; font-size: 1.5rem; cursor: pointer; }
        .modal-close:hover { color: #fff; }
        .markdown-body { background: #1a1a1a; padding: 15px; border-radius: 6px; border: 1px solid #333; margin: 15px 0; line-height: 1.5; }
        
        .gps-step-box { background: #181818; padding: 15px; border-radius: 6px; border: 1px solid #333; margin-top: 15px; }
        .password-form { display: flex; gap: 10px; margin: 10px 0; }
        .input-key { flex: 1; padding: 10px; background: #2b2b2b; border: 1px solid #444; color: #fff; border-radius: 4px; box-sizing: border-box; }
        .btn-check { width: 100%; padding: 12px; background: #28a745; border: none; color: #fff; font-weight: bold; border-radius: 4px; cursor: pointer; margin-top: 10px; }
        .status-msg { margin-top: 10px; font-weight: bold; }

        .client-debug-box { background: #000; border: 1px solid #ffc107; padding: 10px; border-radius: 4px; margin-top: 15px; font-family: monospace; font-size: 0.85rem; color: #ffc107; max-height: 150px; overflow-y: auto; }
        .client-debug-title { font-weight: bold; border-bottom: 1px dashed #ffc107; padding-bottom: 4px; margin-bottom: 6px; }

        .debug-console { background: #0a0a0a; border-left: 4px solid #ffc107; margin-top: 20px; }
        .debug-console h3 { color: #ffc107; margin-top: 0; }
        .debug-log { color: #aaa; margin: 5px 0; font-family: monospace; white-space: pre-wrap; word-break: break-all; }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>Protocoles d'Extraction</h1>
            <div>
                <a href="?format=json" target="_blank" class="btn btn-json">Export JSON</a>
            </div>
        </header>

        <div class="section">
            <h2>Protocoles Activés (<?= count($activeProtocoles) ?>) :</h2>
            <?php if (empty($activeProtocoles)): ?>
                <p>Aucun protocole n'est actuellement activé.</p>
            <?php else: ?>
                <div class="grid">
                    <?php foreach ($activeProtocoles as $code =>$proto): ?>
                        <div class="card" style="border-left-color: <?= htmlspecialchars($proto['couleur'] ?? '#007bff') ?>;" onclick="openProtocolModal('<?= htmlspecialchars($code) ?>')">
                            <h3 style="color: <?= htmlspecialchars($proto['couleur'] ?? '#007bff') ?>;">[<?= htmlspecialchars($code) ?>] <?= htmlspecialchars($proto['nom'] ?? 'Sans Nom') ?></h3>
                            <p>Cliquez pour consulter le protocole et déchiffrer l'itinéraire GPS.</p>
                            <div class="card-click-hint">Ouvrir le protocole &rarr;</div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </div>

        <?php if (isset($_GET['debug'])): ?>
        <div class="section debug-console">
            <h3>Console de débogage PHP (protocoles.php)</h3>
            <?php foreach ($debugLogs as $index =>$log): ?>
                <div class="debug-log">[<?= $index ?>] > <?= htmlspecialchars($log) ?></div>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>
    </div>

    <!-- Modale de détails -->
    <div id="protocolModal" class="modal-overlay">
        <div class="modal-card">
            <button class="modal-close" onclick="closeProtocolModal()">&times;</button>
            <h2 id="modalTitle">Titre du protocole</h2>
            
            <div class="markdown-body" id="modalMarkdown"></div>

            <!-- Module GPS Pas à Pas -->
            <div class="gps-step-box">
                <h4>Séquence de Navigation GPS</h4>
                <label for="clientPassword">Mot de passe de déchiffrement client :</label>
                <div class="password-form">
                    <input type="password" id="clientPassword" class="input-key" placeholder="Entrez la clé client..." oninput="updateGpsUI()" onkeydown="handleKeyPress(event)">
                    <button type="button" class="btn-submit" onclick="updateGpsUI()">Déchiffrer</button>
                </div>
                
                <div id="gpsStepInfo">Veuillez saisir votre mot de passe pour afficher les points GPS.</div>
                <div id="gpsStatus" class="status-msg"></div>
                
                <!-- Bloc de debug en temps réel -->
                <div class="client-debug-box">
                    <div class="client-debug-title">&gt;_ Console de déchiffrement Temps Réel</div>
                    <div id="clientDebugLog">Attente d'une saisie de clé...</div>
                </div>

                <button id="btnCheckGps" class="btn-check" style="display:none;" onclick="checkUserLocation()">Démarrer le suivi GPS en temps réel</button>
                <div id="mapsLinkBox" style="margin-top: 15px;"></div>
            </div>
        </div>
    </div>

    <script>
        const protocolesData = <?= json_encode($activeProtocoles, JSON_UNESCAPED_UNICODE) ?>;
        let currentProtoCode = null;
        let currentPointIndex = 0;
        let decryptedCoords = null;
        let geoWatchId = null;

        function logClientDebug(message, clear = false) {
            const container = document.getElementById('clientDebugLog');
            if (clear && container) {
                container.innerHTML = '';
            }
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
            document.getElementById('modalTitle').style.color = proto.couleur || '#ffffff';
            document.getElementById('modalMarkdown').innerHTML = proto.description_html || '';

            document.getElementById('clientPassword').value = '';
            logClientDebug("Modal ouverte pour : " + code, true);
            
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

        // Déchiffrement AES-256-CBC via WebCrypto API
        async function decryptAESCBC(encryptedBase64, password, coordName) {
            try {
                logClientDebug(`Déchiffrement (${coordName}) : "${encryptedBase64.substring(0, 15)}..."`);
                const rawData = Uint8Array.from(atob(encryptedBase64), c => c.charCodeAt(0));
                
                if (rawData.length < 17) {
                    logClientDebug(`&rarr; [ÉCHEC ${coordName}] Taille de données insuffisante (< 17 octets).`);
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
            logClientDebug("--- Mise à jour du point GPS ---", true);
            const proto = protocolesData[currentProtoCode];
            const points = proto.points || [];
            const password = document.getElementById('clientPassword').value;

            if (points.length === 0) {
                logClientDebug("Aucun point GPS enregistré.");
                document.getElementById('gpsStepInfo').innerText = "Aucune coordonnée GPS pour ce protocole.";
                document.getElementById('btnCheckGps').style.display = 'none';
                document.getElementById('mapsLinkBox').innerHTML = '';
                stopGeoTracking();
                return;
            }

            const targetPoint = points[currentPointIndex];
            logClientDebug(`Traitement du point ${currentPointIndex + 1}/${points.length}`);

            if (!password) {
                logClientDebug("Attente de la clé client...");
                document.getElementById('gpsStepInfo').innerText = "Saisissez votre clé client pour déchiffrer l'étape.";
                document.getElementById('gpsStatus').innerText = "";
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
                logClientDebug("Échec de déchiffrement du point courant.");
                document.getElementById('gpsStepInfo').innerText = "Mot de passe incorrect ou données corrompues.";
                document.getElementById('gpsStatus').innerText = "";
                document.getElementById('btnCheckGps').style.display = 'none';
                document.getElementById('mapsLinkBox').innerHTML = '';
                stopGeoTracking();
                return;
            }

            decryptedCoords = { lat: parseFloat(lat), lng: parseFloat(lng) };
            logClientDebug(`Point courant déchiffré : (${decryptedCoords.lat}, ${decryptedCoords.lng})`);

            document.getElementById('btnCheckGps').style.display = 'block';
            document.getElementById('btnCheckGps').innerText = "Démarrer le suivi GPS en temps réel";
            document.getElementById('gpsStepInfo').innerHTML = `
                <strong>Point ${currentPointIndex + 1} / ${points.length} :</strong> ${targetPoint.nom || 'Point ' + (currentPointIndex + 1)}<br>
                <strong>Cible :</strong> ${decryptedCoords.lat}, ${decryptedCoords.lng}
            `;
            document.getElementById('gpsStatus').innerText = "Clé valide. Appuyez sur le bouton pour lancer le suivi de position.";
            document.getElementById('gpsStatus').style.color = "#28a745";
            
            document.getElementById('mapsLinkBox').innerHTML = `
                <a href="https://maps.google.com/?q=${decryptedCoords.lat},${decryptedCoords.lng}" target="_blank" style="color:#17a2b8;">Ouvrir l'étape dans Google Maps</a>
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
                logClientDebug("Suivi GPS arrêté.");
            }
        }

        function checkUserLocation() {
            const statusBox = document.getElementById('gpsStatus');
            const proto = protocolesData[currentProtoCode];

            if (!navigator.geolocation) {
                statusBox.innerText = "La géolocalisation n'est pas supportée par votre appareil.";
                statusBox.style.color = "#dc3545";
                return;
            }

            if (geoWatchId !== null) {
                stopGeoTracking();
                statusBox.innerText = "Suivi GPS en pause.";
                document.getElementById('btnCheckGps').innerText = "Démarrer le suivi GPS en temps réel";
                return;
            }

            statusBox.innerText = "Recherche de la position en cours...";
            statusBox.style.color = "#17a2b8";
            document.getElementById('btnCheckGps').innerText = "Arrêter le suivi GPS";

            geoWatchId = navigator.geolocation.watchPosition(
                (position) => {
                    const userLat = position.coords.latitude;
                    const userLng = position.coords.longitude;
                    const distance = calculateDistanceInKm(userLat, userLng, decryptedCoords.lat, decryptedCoords.lng);

                    logClientDebug(`GPS : [${userLat.toFixed(5)}, ${userLng.toFixed(5)}] | Distance cible : ${distance.toFixed(3)} km`);

                    if (distance <= 1.0) {
                        stopGeoTracking();
                        
                        if (currentPointIndex + 1 < proto.points.length) {
                            statusBox.innerText = `Point ${currentPointIndex + 1} atteint ! (${(distance * 1000).toFixed(0)}m). Passage au point suivant...`;
                            statusBox.style.color = "#28a745";
                            
                            currentPointIndex++;
                            setTimeout(() => {
                                updateGpsUI();
                                checkUserLocation();
                            }, 2500);
                        } else {
                            statusBox.innerText = "Félicitations ! Dernier point d'extraction atteint. Protocole terminé.";
                            statusBox.style.color = "#28a745";
                            document.getElementById('btnCheckGps').style.display = 'none';
                        }
                    } else {
                        statusBox.innerText = `En route... Distance du point ${currentPointIndex + 1} : ${distance.toFixed(2)} km (Zone de validation : < 1 km)`;
                        statusBox.style.color = "#ffc107";
                    }
                },
                (err) => {
                    logClientDebug(`Erreur de géolocalisation : ${err.message}`);
                    statusBox.innerText = "Erreur d'accès au GPS. Veuillez vérifier vos autorisations.";
                    statusBox.style.color = "#dc3545";
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
