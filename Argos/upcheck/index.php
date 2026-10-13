<?php
/**
 * Argos - Interface Tactique d'Affichage (AubeZero)
 * @Author : ROYJohan
 * @Version : 2.0.0
 * @Date : 2026-10-13
 * @Desc : Interface de supervision pure du module Argos (Affichage d'état et action de Check)
 */

// Inclusion exclusive de la logique métier pour récupérer les données de l'état
$fichierFunctions = __DIR__ . '/function.php';
$etatActuel = [];
$erreurMessage = '';

if (file_exists($fichierFunctions)) {
    require_once $fichierFunctions;
    if (class_exists('UpCheck')) {
        $argosInstance = new UpCheck();
        if (method_exists($argosInstance, 'readState')) {
            $etatActuel = $argosInstance->readState();
        }
    }
} else {
    $erreurMessage = "Fichier de fonctions introuvable.";
}

// Gestion de l'action de check si déclenchée par l'interface
$actionFeedback = null;
if (isset($_POST['action_check'])) {
    try {
        if (class_exists('UpCheck')) {
            $checker = new UpCheck();
            if (method_exists($checker, 'UpCheck')) {
                $checker->UpCheck();
                // Relecture de l'état après le check
                $etatActuel = $checker->readState();
                $actionFeedback = ['succes' => true, 'message' => "Vérification tactique (UpCheck) exécutée avec succès."];
            }
        }
    } catch (Exception $e) {
        $actionFeedback = ['succes' => false, 'message' => "Erreur lors du check : " . $e->getMessage()];
    }
}

$isUp = $etatActuel['is_up'] ?? false;
$httpCode = $etatActuel['http_code'] ?? 'N/A';
$lastCheck = $etatActuel['last_check'] ?? 'Inconnu';
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARGOS // SUPERVISION TACTIQUE</title>
    <style>
        :root {
            --bg-primary: #050b14;
            --bg-card: #0a1728;
            --border-color: #00e5ff;
            --border-dim: #0056b3;
            --text-main: #d0f0ff;
            --text-bright: #00e5ff;
            --success-green: #00ff66;
            --alert-red: #ff3333;
            --font-mono: 'Consolas', 'Courier New', monospace;
        }

        body {
            background-color: var(--bg-primary);
            color: var(--text-main);
            font-family: var(--font-mono);
            margin: 0;
            padding: 30px;
        }

        .container {
            max-width: 900px;
            margin: 0 auto;
        }

        .hud-panel {
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            box-shadow: 0 0 15px rgba(0, 229, 255, 0.2);
            padding: 30px;
            border-radius: 4px;
        }

        h1 {
            color: var(--text-bright);
            text-transform: uppercase;
            letter-spacing: 2px;
            border-bottom: 2px solid var(--border-dim);
            padding-bottom: 10px;
            margin-top: 0;
        }

        p {
            font-size: 0.9rem;
            line-height: 1.5;
            color: #a0c0d0;
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 25px 0;
        }

        .metric-card {
            background: rgba(0, 229, 255, 0.03);
            border: 1px solid var(--border-dim);
            padding: 20px;
            text-align: center;
        }

        .metric-title {
            font-size: 0.75rem;
            color: #7090b0;
            text-transform: uppercase;
            margin-bottom: 8px;
        }

        .metric-value {
            font-size: 1.2rem;
            font-weight: bold;
        }

        .status-ok {
            color: var(--success-green);
        }

        .status-down {
            color: var(--alert-red);
        }

        .action-bar {
            margin-top: 30px;
            display: flex;
            gap: 15px;
        }

        .hud-button {
            background: rgba(0, 229, 255, 0.1);
            border: 1px solid var(--border-color);
            color: var(--text-bright);
            padding: 12px 25px;
            font-family: var(--font-mono);
            font-weight: bold;
            text-transform: uppercase;
            cursor: pointer;
            transition: all 0.2s ease;
        }

        .hud-button:hover {
            background: rgba(0, 229, 255, 0.25);
            box-shadow: 0 0 10px rgba(0, 229, 255, 0.4);
        }

        /* Toast style Discord en bas à droite */
        .discord-toast {
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #111822;
            border-left: 4px solid var(--border-color);
            border-top: 1px solid var(--border-dim);
            border-right: 1px solid var(--border-dim);
            border-bottom: 1px solid var(--border-dim);
            padding: 15px 20px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.7);
            font-size: 0.85rem;
            max-width: 350px;
            z-index: 1000;
        }

        .discord-toast.success {
            border-left-color: var(--success-green);
        }

        .discord-toast.error {
            border-left-color: var(--alert-red);
        }

        .nav-back {
            display: inline-block;
            margin-bottom: 20px;
            color: var(--border-color);
            text-decoration: none;
            font-size: 0.85rem;
        }

        .nav-back:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>

<div class="container">
    <a href="index.php" class="nav-back">&lt; RETOUR AU HUB CENTRAL</a>
    
    <div class="hud-panel">
        <h1>[ARGOS] // SUPERVISION DU MODULE</h1>
        <p>État opérationnel et télémétrie de surveillance du service distant configuré.</p>

        <div class="metrics-grid">
            <div class="metric-card">
                <div class="metric-title">État du Service</div>
                <div class="metric-value">
                    <?php if ($isUp): ?>
                        <span class="status-ok">● OPÉRATIONNEL</span>
                    <?php else: ?>
                        <span class="status-down">● INACCESSIBLE</span>
                    <?php endif; ?>
                </div>
            </div>

            <div class="metric-card">
                <div class="metric-title">Code HTTP</div>
                <div class="metric-value" style="color: var(--text-bright);"><?= htmlspecialchars((string)$httpCode) ?></div>
            </div>

            <div class="metric-card">
                <div class="metric-title">Dernière Vérification</div>
                <div class="metric-value" style="font-size: 0.85rem; color: #a0c0d0;"><?= htmlspecialchars((string)$lastCheck) ?></div>
            </div>
        </div>

        <form method="POST" class="action-bar">
            <button type="submit" name="action_check" value="1" class="hud-button">Lancer une vérification (Check)</button>
        </form>
    </div>
</div>

<?php if ($actionFeedback): ?>
    <div class="discord-toast <?= $actionFeedback['succes'] ? 'success' : 'error' ?>">
        <strong>[ARGOS NOTIFICATION]</strong><br>
        <?= htmlspecialchars($actionFeedback['message']) ?>
    </div>
    <script>
        setTimeout(() => {
            const toast = document.querySelector('.discord-toast');
            if (toast) toast.style.display = 'none';
        }, 5000);
    </script>
<?php endif; ?>

</body>
</html>
