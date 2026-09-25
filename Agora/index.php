<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AubeZero — Dashboard Tactique DomoNas</title>
    
    <!--
    # Athena - Dashboard DomoNas
    # @Author : ROYJohan
    # @Version : 2.0
    # @Date : 2026-09-25
    # @Desc : Tableau de bord HUD militaire futuriste pour la supervision et le contrôle des services DomoNas
    -->

    <link rel="stylesheet" href="sources/style.css">
    <style>
        /* CSS Intégré - Charte Graphique HUD Militaire AubeZero */
        :root {
            --bg-color: #050b14;
            --panel-bg: rgba(10, 25, 47, 0.85);
            --border-color: #00a2ff;
            --text-color: #cce7ff;
            --primary-blue: #00e5ff;
            --status-ok: #00ff66;
            --status-error: #ff3333;
            --font-mono: "Courier New", Courier, monospace;
        }

        body {
            background-color: var(--bg-color);
            color: var(--text-color);
            font-family: var(--font-mono);
            margin: 0;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        .glass {
            background: var(--panel-bg);
            border: 1px solid var(--border-color);
            box-shadow: 0 0 15px rgba(0, 229, 255, 0.2);
            border-radius: 4px;
            padding: 20px;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 2px solid var(--border-color);
            padding-bottom: 10px;
            margin-bottom: 20px;
            text-transform: uppercase;
        }

        h2 {
            margin: 0;
            color: var(--primary-blue);
            letter-spacing: 2px;
        }

        .badge {
            padding: 4px 8px;
            border-radius: 2px;
            font-size: 0.85em;
            font-weight: bold;
        }

        .badge-ok { background: rgba(0, 255, 102, 0.15); color: var(--status-ok); border: 1px solid var(--status-ok); }
        .badge-error { background: rgba(255, 51, 51, 0.15); color: var(--status-error); border: 1px solid var(--status-error); }
        .badge-info { background: rgba(0, 229, 255, 0.15); color: var(--primary-blue); border: 1px solid var(--primary-blue); }

        .service-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
            gap: 15px;
        }

        .service-card {
            background: rgba(0, 162, 255, 0.05);
            border: 1px solid rgba(0, 229, 255, 0.3);
            padding: 15px;
            text-align: center;
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .service-card:hover {
            border-color: var(--primary-blue);
            box-shadow: 0 0 10px rgba(0, 229, 255, 0.4);
            background: rgba(0, 162, 255, 0.15);
        }

        .service-card.disabled {
            opacity: 0.5;
            cursor: not-allowed;
            border-color: var(--status-error);
        }

        .service-icon {
            width: 48px;
            height: 48px;
            margin-bottom: 10px;
        }

        .service-name {
            font-weight: bold;
            color: #ffffff;
            margin-bottom: 8px;
            text-transform: uppercase;
        }

        /* Fenêtre Modale HUD */
        .modal {
            display: none;
            position: fixed;
            top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0, 0, 0, 0.85);
            justify-content: center;
            align-items: center;
            z-index: 1000;
        }

        .modal-content {
            background: var(--bg-color);
            border: 2px solid var(--primary-blue);
            box-shadow: 0 0 20px rgba(0, 229, 255, 0.5);
            width: 80%;
            max-width: 600px;
            padding: 20px;
            position: relative;
        }

        .modal-close {
            position: absolute;
            top: 10px; right: 15px;
            color: var(--status-error);
            cursor: pointer;
            font-weight: bold;
        }

        /* Toast Erreur Style Discord */
        #toast-container {
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 2000;
        }

        .discord-toast {
            background: #2f3136;
            border-left: 5px solid var(--status-error);
            color: #fff;
            padding: 12px 20px;
            margin-top: 10px;
            border-radius: 4px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
            font-family: sans-serif;
            font-size: 0.9em;
            display: flex;
            align-items: center;
            gap: 10px;
        }
    </style>
</head>

<body>

<div class="container">
    <div class="glass">

        <div class="header">
            <h2>[AUBEZERO] — DASHBOARD DOMONAS</h2>
            <span id="mode" class="badge badge-info">INITIALISATION...</span>
        </div>

        <div class="service-grid" id="grid"></div>

        <div id="logs" class="logs-container" style="display:none;"></div>

    </div>
</div>

<!-- Fenêtre Modale pour Informations Complémentaires -->
<div id="infoModal" class="modal">
    <div class="modal-content">
        <span class="modal-close" onclick="closeModal()">[ FERMER ]</span>
        <h3 id="modalTitle" style="color:var(--primary-blue); margin-top:0;">DÉTAILS MMODULE</h3>
        <div id="modalBody"></div>
    </div>
</div>

<!-- Conteneur de Toasts Discord -->
<div id="toast-container"></div>

<script type="text/javascript" defer>
// ==========================================
// CONFIGURATION ET DEBOGAGE CENTRALISÉ
// ==========================================
const DOMAIN_NAS = "dsm.royjohan.fr";
const DOMAIN_API = "api.royjohan.fr";
const REMOTE_JSON = `https://${DOMAIN_API}/services.json`;

const params = new URLSearchParams(location.search);
const isLogsView = params.get("view") === "logs";
const isLAN = location.hostname.startsWith("192.168.") || location.hostname === "localhost";

document.getElementById("mode").textContent = isLAN ? "MODE RÉSEAU LOCAL (LAN)" : "MODE RESEAU DISTANT (WAN)";

const grid = document.getElementById("grid");
const logsBox = document.getElementById("logs");

// ==========================================
// SYSTÈME DE JOURNALISATION MNÉMOSYNE
// ==========================================
function getLogDateFormatted() {
    const d = new Date();
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hours = String(d.getHours()).padStart(2, '0');
    const mins = String(d.getMinutes()).padStart(2, '0');
    
    return {
        filename: `${year}${month}${day}.log`, // AAAAMMDD.log
        timestamp: `${year}${month}${day}${hours}${mins}` // AAAAMMDDHHMM
    };
}

async function writeMnemosyneLog(indicator, message) {
    const { filename, timestamp } = getLogDateFormatted();
    const logLine = `${timestamp}-[ATHENA]-[${indicator}] - ${message}`;
    
    // Enregistrement réseau en arrière-plan (si accessible)
    try {
        fetch(`https://${DOMAIN_API}/mnemosyne/write`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ logfile: filename, line: logLine })
        }).catch(() => {}); // Mode silencieux si indisponible (Air-Gap)
    } catch (_) {}
}

// Initialisation de la session de journalisation
writeMnemosyneLog("👉", "Initialisation de l'interface Dashboard DomoNas");

// ==========================================
// SYSTEME DE NOTIFICATION TOAST (DISCORD STYLE)
// ==========================================
function showDiscordToast(message) {
    const container = document.getElementById("toast-container");
    const toast = document.createElement("div");
    toast.className = "discord-toast";
    toast.innerHTML = `<span>⚠️</span> <div><strong>Alerte Système :</strong> ${message}</div>`;
    
    container.appendChild(toast);
    setTimeout(() => {
        toast.remove();
    }, 5000);
}

// ==========================================
// MODALE H.U.D
// ==========================================
function openModal(title, content) {
    document.getElementById("modalTitle").textContent = title;
    document.getElementById("modalBody").innerHTML = content;
    document.getElementById("infoModal").style.display = "flex";
}

function closeModal() {
    document.getElementById("infoModal").style.display = "none";
}

// ==========================================
// ACCÈS ET REQUÊTES RÉSEAU SÉCURISÉES
// ==========================================
const fetchWithTimeout = (url, timeout = 2500) => {
    return Promise.race([
        fetch(url, { method: "GET", mode: "cors" }),
        new Promise((_, reject) => setTimeout(() => reject(new Error("Délai d'attente dépassé")), timeout))
    ]);
};

// Chargement des services (Distant -> Local Fallback)
async function loadServices() {
    try {
        const remote = await fetchWithTimeout(REMOTE_JSON);
        const json = await remote.json();
        writeMnemosyneLog("+", "Chargement réussi de la configuration JSON distante");
        return json;
    } catch (e) {
        writeMnemosyneLog("~", "Échec accès serveur distant → basculement en mode local");
    }

    try {
        const local = await fetchWithTimeout("sources/services.json");
        const json = await local.json();
        writeMnemosyneLog("+", "Chargement réussi du fichier services.json local");
        return json;
    } catch (err) {
        writeMnemosyneLog("-", "Erreur critique : Impossible de charger la liste des services");
        showDiscordToast("Impossible de charger les données des services.");
        return [];
    }
}

// Vérification de la disponibilité d'un service
const checkService = (url, timeout = 2500) => {
    return Promise.race([
        fetch(url, { method: "GET", mode: "no-cors" }),
        new Promise((_, reject) => setTimeout(() => reject(new Error("Hors ligne")), timeout))
    ]);
};

// ==========================================
// MODE LOGS MNÉMOSYNE
// ==========================================
async function loadLogs() {
    grid.style.display = "none";
    logsBox.style.display = "block";
    logsBox.innerHTML = "<h3>JOURNAL TACTIQUE MNÉMOSYNE</h3><pre>CHARGEMENT...</pre>";

    const { filename } = getLogDateFormatted();

    try {
        const res = await fetchWithTimeout(`sources/${filename}`, 2500);
        const text = await res.text();
        logsBox.innerHTML = `<h3>JOURNAL MNÉMOSYNE (${filename})</h3><pre>${text}</pre>`;
        writeMnemosyneLog("✓", "Consultation du fichier log quotidien effectuée");
    } catch (err) {
        logsBox.innerHTML = `<h3>JOURNAL MNÉMOSYNE</h3><pre>Aucun journal disponible pour la journée en cours.</pre>`;
        showDiscordToast("Accès au journal Mnémosyne impossible.");
        writeMnemosyneLog("-", "Échec de lecture du fichier journal local");
    }
}

// ==========================================
// MODE DASHBOARD PRINCIPAL
// ==========================================
function loadDashboard() {
    loadServices().then(services => {
        if (services.length === 0) {
            grid.innerHTML = "<p style='color:var(--status-error)'>AUCUN SERVICE DISPONIBLE.</p>";
            return;
        }

        services.forEach(s => {
            // Attribution dynamique du domaine WAN selon les spécifications
            let url = isLAN ? s.lan : (s.wan || `https://${DOMAIN_NAS}/${s.name.toLowerCase()}`);
            const icon = `sources/images/${s.name}.png`;

            const card = document.createElement("div");
            card.className = "service-card";
            card.id = `card-${s.name}`;
            
            // Clic principal : Ouverture du service
            card.onclick = (e) => {
                if (e.target.classList.contains('info-btn')) return;
                window.open(url, "_blank");
            };

            card.innerHTML = `
                <img src="${icon}" class="service-icon" onerror="this.src='sources/images/default.png'">
                <div class="service-name">${s.name}</div>
                <div id="status-${s.name}"><span class="badge badge-info">TEST...</span></div>
                <button class="info-btn" style="margin-top:10px; background:none; border:1px solid var(--primary-blue); color:var(--primary-blue); cursor:pointer; font-size:0.7em;" 
                    onclick="openModal('${s.name}', '<strong>URL :</strong> ${url}<br><strong>Description :</strong> ${s.description || 'Module de la suite AubeZero.'}')">
                    + DÉTAILS
                </button>
            `;

            grid.appendChild(card);

            // Test de connectivité
            checkService(url)
                .then(() => {
                    document.getElementById(`status-${s.name}`).innerHTML = "<span class='badge badge-ok'>OPÉRATIONNEL</span>";
                    writeMnemosyneLog("+", `Service ${s.name} en ligne [${url}]`);
                })
                .catch(() => {
                    // Repli WAN -> LAN en mode hors-ligne
                    if (!isLAN && s.lan) {
                        writeMnemosyneLog("~", `Service ${s.name} indisponible en WAN → essai en LAN`);
                        url = s.lan;
                        checkService(url)
                            .then(() => {
                                document.getElementById(`status-${s.name}`).innerHTML = "<span class='badge badge-ok'>EN LIGNE (LAN)</span>";
                                card.onclick = (e) => { if (!e.target.classList.contains('info-btn')) window.open(url, "_blank"); };
                            })
                            .catch(() => {
                                setServiceDown(s.name);
                            });
                        return;
                    }
                    setServiceDown(s.name);
                });
        });
    });
}

function setServiceDown(serviceName) {
    document.getElementById(`status-${serviceName}`).innerHTML = "<span class='badge badge-error'>INACCESSIBLE</span>";
    document.getElementById(`card-${serviceName}`).classList.add("disabled");
    writeMnemosyneLog("-", `Alerte : Service ${serviceName} hors-ligne`);
    showDiscordToast(`Le service ${serviceName} est actuellement hors-ligne.`);
}

// ROUTAGE
if (isLogsView) {
    loadLogs();
} else {
    loadDashboard();
}
</script>

</body>
</html>
