<?php
	/**
	 * AubeZero // Protocoles d'Extraction (Interface HUD)
	 * @Author : ROYJohan
	 * @Version : 2.5.0
	 * @Date : 2026-10-12
	 * @Desc : Interface d'affichage pure avec déchiffrement manuel par clé secrète brute
	 */
	session_start();
	require_once __DIR__ . '/function.php';
	$debugLogs = [];
	function parseMarkdown($text) {
		if (empty($text)) {
			return '';
		}
		$text = preg_replace('/^### (.*$)/im', '<h3>$1</h3>',$text);
		$text = preg_replace('/^## (.*$)/im', '<h2>$1</h2>',$text);
		$text = preg_replace('/^# (.*$)/im', '<h1>$1</h1>', $text);$text = preg_replace('/\*\*(.*?)\*\*/s', '<strong>$1</strong>', $text);$text = preg_replace('/\*([^\*]+)\*/s', '<em>$1</em>',$text);
		$text = preg_replace('/^\* (.*$)/im', '<li>$1</li>',$text);
		return nl2br($text);
	}
	$manager = new Protocoles();
	$allProtocoles = $manager->chargerProtocoles();
	$activeProtocoles = [];
	foreach ($allProtocoles as$proto) {
		$code =$proto['nom'] ?? 'INCONNU';
		if (!empty($proto['actif'])) {$proto['description_html'] = parseMarkdown($proto['description'] ?? '');$activeProtocoles[$code] =$proto;
		}
	}
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
			}
			.container { max-width: 1100px; margin: 0 auto; }
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
			}
			.section-title {
				margin-top: 0;
				color: var(--text-bright);
				font-size: 1.1rem;
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
			}
			.card:hover {
				border-color: var(--border-color);
				box-shadow: 0 0 12px rgba(0, 229, 255, 0.3);
			}
			.card h3 { margin-top: 0; text-transform: uppercase; }
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
			.modal-overlay.active { display: flex; }
			.modal-card {
				background: var(--bg-card);
				border: 1px solid var(--border-color);
				width: 90%;
				max-width: 700px;
				padding: 25px;
				position: relative;
				max-height: 85vh;
				overflow-y: auto;
			}
			.modal-close {
				position: absolute;
				top: 15px; right: 15px;
				background: transparent;
				border: 1px solid var(--toast-red);
				color: var(--toast-red);
				padding: 4px 10px;
				cursor: pointer;
				font-weight: bold;
			}
			.markdown-body {
				background: rgba(0, 10, 20, 0.8);
				padding: 15px;
				border: 1px solid var(--border-dim);
				margin: 15px 0;
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
			}
			.toast-container {
				position: fixed;
				top: 20px; right: 20px;
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
				font-size: 0.85rem;
			}
			.toast-discord.success { border-left-color: var(--success-green); }
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
		</style>
	</head>
	<body>
		<div class="toast-container" id="toastContainer"></div>
		<div class="container">
			<header>
				<h1>MODULE // PROTOCOLES D'EXTRACTION</h1>
				<div><a href="?format=json" target="_blank" class="btn-hud">Export JSON</a></div>
			</header>
			<div class="section">
				<div class="section-title">Protocoles Activés (<?= count($activeProtocoles) ?>)</div>
				<?php if (empty($activeProtocoles)): ?>
					<p style="color: #888;">Aucun protocole d'extraction n'est actuellement actif.</p>
				<?php else: ?>
					<div class="grid">
						<?php foreach ($activeProtocoles as $code =>$proto): ?>
							<div class="card" onclick="openProtocolModal('<?= htmlspecialchars($code, ENT_QUOTES) ?>')">
								<h3>[<?= htmlspecialchars($code) ?>]</h3>
								<p style="font-size: 0.85rem; color: #aaa;">Sélectionner pour initialiser le déchiffrement.</p>
								<div style="font-size: 0.75rem; color: var(--text-bright);">ACCÉDER AU PROTOCOLE ►</div>
							</div>
						<?php endforeach; ?>
					</div>
				<?php endif; ?>
			</div>
		</div>
		<div id="protocolModal" class="modal-overlay">
			<div class="modal-card">
				<button class="modal-close" onclick="closeProtocolModal()">[X] FERMER</button>
				<h2 id="modalTitle" style="margin-top:0; font-size: 1.2rem; text-transform: uppercase;">Titre</h2>
				<div class="markdown-body" id="modalMarkdown"></div>
				<div class="gps-step-box">
					<h4 style="margin-top:0; color: var(--text-bright); text-transform: uppercase; font-size: 0.9rem;">Séquence de Navigation GPS</h4>
					<label style="font-size: 0.8rem; color: #aaa;">Clé Secrète de Déchiffrement :</label>
					<div class="password-form">
						<input type="password" id="clientPassword" class="input-key" placeholder="Saisir la clé secrète..." onkeydown="handleKeyPress(event)">
						<button type="button" class="btn-hud" onclick="updateGpsUI()">Déchiffrer</button>
					</div>
					<div id="gpsStepInfo" style="font-size: 0.85rem; margin-top: 10px;">Saisissez votre clé et cliquez sur "Déchiffrer".</div>
					<div class="client-debug-box">
						<div style="font-weight:bold; border-bottom:1px dashed var(--border-dim); padding-bottom:4px; margin-bottom:6px; color:var(--warning-amber);">&gt;_ Console de Déchiffrement</div>
						<div id="clientDebugLog">En attente d'action...</div>
					</div>
					<button id="btnCheckGps" class="btn-hud" style="display:none; width: 100%; margin-top: 15px;" onclick="checkUserLocation()">Démarrer le suivi GPS en temps réel</button>
					<div id="mapsLinkBox" style="margin-top: 12px; font-size: 0.85rem;"></div>
				</div>
			</div>
		</div>
		<script>
			const protocolesData = <?= json_encode($activeProtocoles, JSON_UNESCAPED_UNICODE) ?>;
			let currentProtoCode = null;
			let decryptedCoords = null;
			let geoWatchId = null;
			function showToast(message, title = "Alerte Système", type = "error") {
				const container = document.getElementById('toastContainer');
				const toast = document.createElement('div');
				toast.className = 'toast-discord '+type;
				toast.innerHTML = '<strong>'+title+'</strong><br>'+message;
				container.appendChild(toast);
				setTimeout(() => toast.remove(), 4000);
			}
			function logClientDebug(message, clear = false) {
				const container = document.getElementById('clientDebugLog');
				if (clear) container.innerHTML = '';
				container.innerHTML += '<div>['+new Date().toLocaleTimeString()+'] '+message+'</div>';
				container.scrollTop = container.scrollHeight;
			}
			function openProtocolModal(code) {
				currentProtoCode = code;
				decryptedCoords = null;
				const proto = protocolesData[code];
				if (!proto) return;
				document.getElementById('modalTitle').innerText = '[' + code + '] ' + (proto.nom || '');
				document.getElementById('modalMarkdown').innerHTML = proto.description_html || '';
				document.getElementById('clientPassword').value = '';            
				logClientDebug("Modal ouverte pour : " + code, true);
				stopGeoTracking();            
				document.getElementById('gpsStepInfo').innerText = "Saisissez votre clé et cliquez sur 'Déchiffrer'.";
				document.getElementById('btnCheckGps').style.display = 'none';
				document.getElementById('mapsLinkBox').innerHTML = '';
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
			function bufferToHex(buffer) {
				return Array.from(new Uint8Array(buffer))
				.map(b => b.toString(16).padStart(2, '0'))
				.join('');
			}
			async function decryptAESCBC(encryptedBase64, password, coordName) {
				try {
					console.log(password);
					const rawData = Uint8Array.from(atob(encryptedBase64), c => c.charCodeAt(0));
					if (rawData.length < 17) return null;
					const iv = rawData.slice(0, 16);
					const cipherText = rawData.slice(16);
					const enc = new TextEncoder();
					const sha1Buffer = await window.crypto.subtle.digest('SHA-1', enc.encode(password));
					console.log("SHA-1 Hex:", bufferToHex(sha1Buffer));
					const keyBuffer = await window.crypto.subtle.digest('SHA-256', sha1Buffer);
					console.log("SHA-256 Hex:", bufferToHex(keyBuffer));
					const key = await window.crypto.subtle.importKey(
						"raw", keyBuffer, { name: "AES-CBC", length: 256 }, false, ["decrypt"]
					);
					const decrypted = await window.crypto.subtle.decrypt({ name: "AES-CBC", iv: iv }, key, cipherText);
					logClientDebug('Déchiffrement '+coordName+' réussi via SHA-1 + SHA-256.');
					return new TextDecoder().decode(decrypted);
				} 
				catch (e) {
					try {
						const rawData = Uint8Array.from(atob(encryptedBase64), c => c.charCodeAt(0));
						const iv = rawData.slice(0, 16);
						const cipherText = rawData.slice(16);
						const enc = new TextEncoder();
						const keyBufferFallback = await window.crypto.subtle.digest('SHA-256', enc.encode(password));
						const keyFallback = await window.crypto.subtle.importKey(
							"raw", keyBufferFallback, { name: "AES-CBC", length: 256 }, false, ["decrypt"]
						);
						const decryptedFallback = await window.crypto.subtle.decrypt(
							{ name: "AES-CBC", iv: iv }, keyFallback, cipherText
						);
						logClientDebug('Déchiffrement '+coordName+' réussi via mot de passe direct.');
						return new TextDecoder().decode(decryptedFallback);
					}
					catch (errFallback) {
						logClientDebug('Erreur déchiffrement '+coordName+' : Clé invalide.');
						return null;
					}
				}
			}
			async function updateGpsUI() {
				logClientDebug("--- Lancement du déchiffrement ---", true);
				const proto = protocolesData[currentProtoCode];
				const coordsList = proto.coordonnees || [];
				const password = document.getElementById('clientPassword').value;
				if (coordsList.length === 0) {
					logClientDebug("Aucune coordonnée GPS associée.");
					return;
				}
				if (!password) {
					showToast("Veuillez saisir la clé secrète.", "Clé Requise", "warning");
					return;
				}
				let firstPoint = coordsList[0];
				let lat = firstPoint.lat;
				let lon = firstPoint.lon || firstPoint.lng;
				if (lat) lat = await decryptAESCBC(lat, password, "LAT");
				if (lon) lon = await decryptAESCBC(lon, password, "LON");
				if (!lat || !lon || isNaN(lat) || isNaN(lon)) {
					logClientDebug("Échec : Clé incorrecte ou données corrompues.");
					document.getElementById('gpsStepInfo').innerText = "Clé invalide.";
					document.getElementById('btnCheckGps').style.display = 'none';
					document.getElementById('mapsLinkBox').innerHTML = '';
					showToast("Clé de déchiffrement invalide.", "Erreur", "error");
					return;
				}
				decryptedCoords = { lat: parseFloat(lat), lng: parseFloat(lon) };
				logClientDebug('Succès ! Coordonnées déchiffrées : ('+decryptedCoords.lat+', '+decryptedCoords.lng+')');
				document.getElementById('btnCheckGps').style.display = 'block';
				document.getElementById('gpsStepInfo').innerHTML = '<strong style="color:var(--border-color);">Cible validée</strong><br>Lat: '+decryptedCoords.lat+' | Lon: '+decryptedCoords.lng;
				document.getElementById('mapsLinkBox').innerHTML = '<a href="https://maps.google.com/?q='+decryptedCoords.lat+','+decryptedCoords.lng+'" target="_blank" style="color: var(--border-color);">► Ouvrir dans Google Maps</a>';
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
				}
			}
			function checkUserLocation() {
				if (!navigator.geolocation) {
					showToast("Géolocalisation non supportée.", "Erreur", "error");
					return;
				}
				if (geoWatchId !== null) {
					stopGeoTracking();
					showToast("Suivi GPS suspendu.", "Info", "warning");
					document.getElementById('btnCheckGps').innerText = "DÉMARRER LE SUIVI GPS TEMPS RÉEL";
					return;
				}
				showToast("Acquisition GPS...", "Suivi", "success");
				document.getElementById('btnCheckGps').innerText = "ARRÊTER LE SUIVI GPS";
				geoWatchId = navigator.geolocation.watchPosition(
					(pos) => {
						const dist = calculateDistanceInKm(pos.coords.latitude, pos.coords.longitude, decryptedCoords.lat, decryptedCoords.lng);
						logClientDebug(`Distance de la cible : ${dist.toFixed(3)} km`);
						if (dist <= 1.0) {
							stopGeoTracking();
							showToast("Cible atteinte !", "Succès", "success");
							document.getElementById('btnCheckGps').style.display = 'none';
						}
					},
					(err) => {
						showToast("Erreur GPS : " + err.message, "Erreur", "error");
						stopGeoTracking();
					},
					{ enableHighAccuracy: true, timeout: 10000 }
				);
			}
			document.addEventListener('keydown', (e) => { if (e.key === "Escape") closeProtocolModal(); });
		</script>
	</body>
</html>
