<?php
declare(strict_types=1);
session_start();

// -----------------------------------------------------
// Chargement credentials.env
// -----------------------------------------------------
$envFile = __DIR__ . '/credentials.env';
if (!is_file($envFile)) {
    die('credentials.env manquant');
}

$env = parse_ini_file($envFile, false, INI_SCANNER_RAW);
if ($env === false) {
    die('Impossible de lire credentials.env');
}

$PASSWORD_LOW   = $env['PASSWORD_LOW']   ?? null;
$PATH_KIWIX     = $env['PATH_KIWIX']     ?? null;
$PATH_MNEMOSYNE = $env['PATH_MNEMOSYNE'] ?? null;

if (!$PASSWORD_LOW || !$PATH_KIWIX) {
    die('PASSWORD_LOW ou PATH_KIWIX non défini dans credentials.env');
}

$PATH_KIWIX = rtrim($PATH_KIWIX, DIRECTORY_SEPARATOR);

// -----------------------------------------------------
// LOG AUBEZERO → Mnemosyne
// -----------------------------------------------------
function aubeLog(string $level, string $message): void {
    global $PATH_MNEMOSYNE;

    $mnemo = $PATH_MNEMOSYNE ?: '/etc/AubeZero/Mnemosyne';

    // Dossier + fichier mensuel
    $logDir  = rtrim($mnemo, DIRECTORY_SEPARATOR);
    $logFile = $logDir . '/' . date('Y-m') . '.log';

    // Format AubeZero (simplifié) : YYYYMMDDHHMM-Programme-Message
    $programme = 'ZIMManager';
    $line = sprintf(
        "%s-%s-%s\n",
        date('YmdHi'),
        $programme,
        $message
    );

    if (!is_dir($logDir)) {
        @mkdir($logDir, 0755, true);
    }

    file_put_contents($logFile, $line, FILE_APPEND);
}

// -----------------------------------------------------
// Utilitaires ZIM
// -----------------------------------------------------
function getSafeZimPath(string $fileName, string $baseDir): ?string {
    $basename = basename($fileName);
    $fullPath = $baseDir . DIRECTORY_SEPARATOR . $basename;

    $realBase = realpath($baseDir);
    if ($realBase === false) {
        return null;
    }

    $realFile = realpath($fullPath);

    if ($realFile === false) {
        // Fichier pas encore créé : on normalise
        $normalized = $realBase . DIRECTORY_SEPARATOR . $basename;
        if (str_starts_with($normalized, $realBase)) {
            return $normalized;
        }
        return null;
    }

    if (!str_starts_with($realFile, $realBase)) {
        return null;
    }

    return $realFile;
}

function listZimFiles(string $baseDir): array {
    if (!is_dir($baseDir)) {
        return [];
    }

    $files = [];
    $dh = opendir($baseDir);
    if ($dh === false) {
        return [];
    }

    while (($entry = readdir($dh)) !== false) {
        if ($entry === '.' || $entry === '..') {
            continue;
        }
        if (str_ends_with(strtolower($entry), '.zim')) {
            $files[] = $entry;
        }
    }
    closedir($dh);

    sort($files);
    return $files;
}

// -----------------------------------------------------
// Tâches “asynchrones” (journalisation JSON)
// -----------------------------------------------------
function addTask(string $type, string $target, string $status = 'pending', ?string $info = null): void {
    $task = [
        'id'      => bin2hex(random_bytes(8)),
        'type'    => $type,
        'target'  => $target,
        'status'  => $status,
        'info'    => $info,
        'time'    => date('Y-m-d H:i:s'),
    ];

    $file  = __DIR__ . '/aubezero_zim_tasks.json';
    $tasks = [];

    if (is_file($file)) {
        $json  = file_get_contents($file);
        $tasks = json_decode($json, true);
        if (!is_array($tasks)) {
            $tasks = [];
        }
    }

    $tasks[] = $task;
    file_put_contents($file, json_encode($tasks, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
}

// -----------------------------------------------------
// Token de session (auth ZIM)
// -----------------------------------------------------
function hasZimToken(): bool {
    return !empty($_SESSION['zim_token']);
}

function setZimToken(): void {
    $_SESSION['zim_token'] = bin2hex(random_bytes(16));
}

function clearZimToken(): void {
    unset($_SESSION['zim_token']);
}

// -----------------------------------------------------
// Traitement des actions
// -----------------------------------------------------
$errorMessages = [];
$infoMessages  = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action   = $_POST['action']   ?? null;
    $password = $_POST['password'] ?? null;

    // Auth : si pas de token, on vérifie le mot de passe
    if (!hasZimToken()) {
        if (!$password || !hash_equals($PASSWORD_LOW, $password)) {
            $errorMessages[] = 'Mot de passe invalide.';
            aubeLog('error', 'Tentative d\'action ZIM avec mot de passe invalide');
            $action = null;
        } else {
            setZimToken();
            aubeLog('info', 'Token ZIM créé après mot de passe valide');
        }
    }

    if ($action === 'delete') {
        $targetItem = $_POST['target_item'] ?? '';
        $safePath   = getSafeZimPath($targetItem, $PATH_KIWIX);

        if (!$safePath || !is_file($safePath)) {
            $errorMessages[] = 'Fichier introuvable ou chemin invalide.';
            aubeLog('error', "Suppression échouée pour '$targetItem' (chemin invalide)");
        } else {
            addTask('delete', $targetItem, 'running', 'Suppression en cours');
            if (@unlink($safePath)) {
                aubeLog('info', "Suppression réussie de '$targetItem'");
                addTask('delete', $targetItem, 'done', 'Suppression terminée');
                $infoMessages[] = "Fichier '$targetItem' supprimé.";
            } else {
                aubeLog('error', "Erreur lors de la suppression de '$targetItem'");
                addTask('delete', $targetItem, 'error', 'Erreur de suppression');
                $errorMessages[] = "Erreur lors de la suppression de '$targetItem'.";
            }
        }
    } elseif ($action === 'add') {
        $dirName = trim($_POST['dir_name'] ?? '');
        if ($dirName === '') {
            $errorMessages[] = 'Nom de fichier ZIM invalide.';
            aubeLog('error', 'Création ZIM échouée (nom vide)');
        } else {
            if (!str_ends_with(strtolower($dirName), '.zim')) {
                $dirName .= '.zim';
            }

            $safePath = getSafeZimPath($dirName, $PATH_KIWIX);
            if (!$safePath) {
                $errorMessages[] = 'Chemin invalide pour la création.';
                aubeLog('error', "Création ZIM échouée pour '$dirName' (chemin invalide)");
            } else {
                if (is_file($safePath)) {
                    $errorMessages[] = 'Un fichier ZIM avec ce nom existe déjà.';
                    aubeLog('warning', "Création ZIM refusée, '$dirName' existe déjà");
                } else {
                    addTask('create', $dirName, 'running', 'Création en cours');
                    if (@touch($safePath)) {
                        aubeLog('info', "Création ZIM réussie pour '$dirName'");
                        addTask('create', $dirName, 'done', 'Création terminée');
                        $infoMessages[] = "Fichier ZIM '$dirName' créé.";
                    } else {
                        aubeLog('error', "Erreur lors de la création de '$dirName'");
                        addTask('create', $dirName, 'error', 'Erreur de création');
                        $errorMessages[] = "Erreur lors de la création de '$dirName'.";
                    }
                }
            }
        }
    } elseif ($action === 'update') {
        $file   = $_POST['file']    ?? '';
        $newUrl = trim($_POST['new_url'] ?? '');

        if ($file === '' || $newUrl === '') {
            $errorMessages[] = 'Paramètres de mise à jour invalides.';
            aubeLog('error', 'Update ZIM échouée (paramètres invalides)');
        } else {
            $safePath = getSafeZimPath($file, $PATH_KIWIX);
            if (!$safePath) {
                $errorMessages[] = 'Chemin invalide pour la mise à jour.';
                aubeLog('error', "Update ZIM échouée pour '$file' (chemin invalide)");
            } else {
                addTask('update', $file, 'running', "Mise à jour depuis $newUrl");
                $context = stream_context_create([
                    'http' => [
                        'timeout' => 30,
                    ],
                ]);
                $data = @file_get_contents($newUrl, false, $context);
                if ($data === false) {
                    $errorMessages[] = "Téléchargement impossible depuis l'URL fournie.";
                    aubeLog('error', "Update ZIM échouée pour '$file' (download KO)");
                    addTask('update', $file, 'error', 'Erreur de téléchargement');
                } else {
                    if (@file_put_contents($safePath, $data) !== false) {
                        $infoMessages[] = "Fichier '$file' mis à jour.";
                        aubeLog('info', "Update ZIM réussie pour '$file' depuis '$newUrl'");
                        addTask('update', $file, 'done', 'Mise à jour terminée');
                    } else {
                        $errorMessages[] = "Erreur lors de l'écriture du fichier.";
                        aubeLog('error', "Update ZIM échouée pour '$file' (écriture KO)");
                        addTask('update', $file, 'error', 'Erreur d\'écriture');
                    }
                }
            }
        }
    }
}

// -----------------------------------------------------
// Badges d'état
// -----------------------------------------------------
function getZimStatusBadge(?string $fullPath): array {
    if (!$fullPath || !is_file($fullPath)) {
        return ['label' => 'INCONNU', 'class' => 'badge-unknown'];
    }

    $size = filesize($fullPath);
    if ($size === 0) {
        return ['label' => 'VIDE', 'class' => 'badge-warning'];
    }

    return ['label' => 'OK', 'class' => 'badge-success'];
}

// Liste des fichiers ZIM
$zimFiles = listZimFiles($PATH_KIWIX);
?>
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ZIM Manager</title>
    <style>
        :root {
            --bg: #0d0f14;
            --card: #161b22;
            --accent: #7c4dff;
            --danger: #ff4d4d;
            --text: #c9d1d9;
            --border: #30363d;
            --success: #2ea043;
            --warning: #f1c40f;
            --unknown: #8b949e;
        }

        body {
            background: var(--bg);
            color: var(--text);
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif;
            padding: 20px;
            margin: 0;
        }

        .container {
            max-width: 1250px;
            margin: 40px auto;
            padding: 0 15px;
        }

        .glass {
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.5);
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 25px;
            flex-wrap: wrap;
            gap: 10px;
        }

        table {
            width: 100%;
            border-collapse: collapse;
        }
        .table-wrapper {
            width: 100%;
            overflow-x: auto;
        }

        td, th {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #21262d;
            white-space: nowrap;
        }

        input {
            background: #0d1117;
            border: 1px solid var(--border);
            color: white;
            padding: 8px;
            border-radius: 6px;
            outline: none;
            width: 100%;
            box-sizing: border-box;
        }

        input:focus {
            border-color: var(--accent);
        }

        .btn {
            background: var(--accent);
            color: white;
            border: none;
            padding: 8px 12px;
            border-radius: 6px;
            cursor: pointer;
            font-weight: bold;
            white-space: nowrap;
            transition: opacity 0.2s, background-color 0.2s;
        }

        .btn:hover {
            opacity: 0.9;
        }

        .btn-upd {
            background: transparent;
            border: 1px solid var(--accent);
            color: var(--accent);
            border-radius: 6px;
            margin-left: 4px;
            font-size: 13px;
        }

        .btn-upd:hover {
            background: var(--accent);
            color: white;
        }

        .btn-del {
            background: transparent;
            color: var(--danger);
            border: 1px solid var(--danger);
            margin-left: 4px;
            font-size: 11px;
        }

        .btn-del:hover {
            background: var(--danger);
            color: white;
        }

        #overlay, #overlay-create, #loader-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(0,0,0,0.85);
            z-index: 90;
            backdrop-filter: blur(5px);
        }

        #update-modal, #create-modal {
            display: none;
            position: fixed;
            top: 50%;
            left: 50%;
            transform: translate(-50%,-50%);
            background: var(--card);
            padding: 25px;
            border: 1px solid var(--accent);
            z-index: 100;
            border-radius: 15px;
            width: 450px;
            max-width: 90%;
        }

        .actions-cell {
            display: flex;
            align-items: center;
            gap: 6px;
            min-width: 250px;
            flex-wrap: wrap;
        }

        #toast-container {
            position: fixed;
            bottom: 20px;
            right: 20px;
            display: flex;
            flex-direction: column;
            gap: 10px;
            z-index: 9999;
        }

        .toast {
            display: flex;
            align-items: flex-start;
            gap: 8px;
            padding: 10px 12px;
            border-radius: 8px;
            background: #202225;
            border-left: 4px solid #f04747;
            color: #ffffff;
            font-size: 0.85rem;
            min-width: 260px;
            max-width: 340px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
            opacity: 0;
            transform: translateX(20px);
            animation: toast-in 0.25s forwards;
        }

        .toast-icon {
            margin-top: 2px;
            font-size: 1rem;
        }

        .toast-close {
            margin-left: auto;
            cursor: pointer;
            opacity: 0.7;
        }

        .toast-close:hover {
            opacity: 1;
        }

        @keyframes toast-in {
            to {
                opacity: 1;
                transform: translateX(0);
            }
        }

        @keyframes toast-out {
            to {
                opacity: 0;
                transform: translateX(20px);
            }
        }

        .badge {
            display: inline-flex;
            align-items: center;
            padding: 2px 8px;
            border-radius: 999px;
            font-size: 0.75rem;
            font-weight: 600;
            margin-left: 8px;
        }
        .badge-success {
            background: rgba(46,160,67,0.15);
            color: var(--success);
            border: 1px solid rgba(46,160,67,0.5);
        }
        .badge-warning {
            background: rgba(241,196,15,0.15);
            color: var(--warning);
            border: 1px solid rgba(241,196,15,0.5);
        }
        .badge-unknown {
            background: rgba(139,148,158,0.15);
            color: var(--unknown);
            border: 1px solid rgba(139,148,158,0.5);
        }

        #loader-overlay {
            display: none;
            align-items: center;
            justify-content: center;
        }
        .loader {
            border: 4px solid #444;
            border-top: 4px solid var(--accent);
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 0.8s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        @media (max-width: 900px) {
            .header {
                flex-direction: column;
                align-items: flex-start;
            }
            .actions-cell {
                min-width: unset;
                width: 100%;
                justify-content: flex-start;
            }
            table {
                font-size: 0.9rem;
            }
        }

        @media (max-width: 600px) {
            body {
                padding: 10px;
            }
            .container {
                margin: 20px auto;
                padding: 0 10px;
            }
            .glass {
                padding: 15px;
            }
            table {
                display: block;
                overflow-x: auto;
                white-space: nowrap;
            }
            td, th {
                padding: 8px;
                font-size: 0.85rem;
            }
            .btn {
                width: 100%;
                text-align: center;
                padding: 10px;
            }
            .actions-cell {
                flex-direction: column;
                align-items: stretch;
                gap: 8px;
            }
            #toast-container {
                right: 10px;
                left: 10px;
                bottom: 10px;
            }
            #update-modal, #create-modal {
                width: 95%;
                padding: 20px;
            }
        }
    </style>
</head>
<body>
    <div id="loader-overlay">
        <div class="loader"></div>
    </div>

    <div class="container">
        <div class="header">
            <div>
                <h1 style="margin:0; font-weight: 300;">ZIM<span style="color:var(--accent); font-weight: 800;">MANAGER</span></h1>
                <code style="color:#8b949e;"><?php echo htmlspecialchars($PATH_KIWIX, ENT_QUOTES, 'UTF-8'); ?></code>
            </div>
            <form onsubmit="return openCreatePopup(this)" method="POST" style="display:flex; gap:10px; width: 100%; max-width: 400px;">
                <input type="hidden" name="action" value="add">
                <input type="hidden" name="password" class="pass-field">
                <input type="text" name="dir_name" placeholder="Nouveau zim..." required>
                <button type="submit" class="btn" style="width: auto;">CRÉER</button>
            </form>
        </div>

        <div class="glass">
            <div class="table-wrapper">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 50%;">ÉLÉMENT</th>
                            <th style="width: 50%;">ACTIONS</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($zimFiles as $item): ?>
                        <?php
                            $fullPath = getSafeZimPath($item, $PATH_KIWIX);
                            $badge    = getZimStatusBadge($fullPath);
                        ?>
                        <tr>
                            <td>
                                📄 <span style="color:#8b949e;"><?php echo htmlspecialchars($item, ENT_QUOTES, 'UTF-8'); ?></span>
                                <span class="badge <?php echo $badge['class']; ?>">
                                    <?php echo htmlspecialchars($badge['label'], ENT_QUOTES, 'UTF-8'); ?>
                                </span>
                            </td>
                            <td class="actions-cell">
                                <button class="btn btn-upd" onclick="openUpdate('<?php echo htmlspecialchars($item, ENT_QUOTES, 'UTF-8'); ?>')">🔄 Update</button>

                                <form method="POST" onsubmit="return confirmDelete('<?php echo addslashes($item); ?>', this)" style="display:inline;">
                                    <input type="hidden" name="action" value="delete">
                                    <input type="hidden" name="target_item" value="<?php echo htmlspecialchars($item, ENT_QUOTES, 'UTF-8'); ?>">
                                    <input type="hidden" name="password" class="pass-field">
                                    <button type="submit" class="btn btn-del" title="Supprimer">🗑️ SUPPR.</button>
                                </form>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- POPUP UPDATE -->
        <div id="overlay" onclick="closeModal()"></div>

        <div id="update-modal">
            <h3 style="margin:0 0 15px; color:var(--accent);">Mettre à jour</h3>
            <form method="POST" onsubmit="showLoader()">
                <input type="hidden" name="action" value="update">
                <input type="hidden" name="file" id="upd_file">

                <label style="display:block; margin-top:10px; font-size:0.9rem;">Nouvelle URL (.zim)</label>
                <input type="text" name="new_url" id="upd_url" style="margin-top:5px;" required>

                <label style="display:block; margin-top:10px; font-size:0.9rem;">Mot de passe</label>
                <input type="password" name="password" style="margin-top:5px;" required>

                <button class="btn" style="width:100%; margin-top:15px;">Mettre à jour</button>
            </form>
            <button class="btn" onclick="closeModal()" style="width:100%; margin-top:10px; background:#21262d; border:1px solid var(--border);">Annuler</button>
        </div>

        <!-- POPUP CREATE -->
        <div id="overlay-create" onclick="closeCreatePopup()"></div>

        <div id="create-modal">
            <h3 style="margin:0 0 15px; color:var(--accent);">Mot de passe requis</h3>
            <label style="display:block; font-size:0.9rem;">Mot de passe</label>
            <input type="password" id="create-pass" style="margin-top:8px;">
            <button class="btn" onclick="validateCreate()" style="width:100%; margin-top:15px;">Valider</button>
            <button class="btn" onclick="closeCreatePopup()" style="width:100%; margin-top:10px; background:#21262d; border:1px solid var(--border);">Annuler</button>
        </div>

        <div id="toast-container"></div>
    </div>

    <script>
    let createForm = null;

    function showLoader() {
        const overlay = document.getElementById('loader-overlay');
        overlay.style.display = 'flex';
    }

    function hideLoader() {
        const overlay = document.getElementById('loader-overlay');
        overlay.style.display = 'none';
    }

    function confirmDelete(name, form) {
        const pass = prompt(`⚠️ SUPPRESSION DÉFINITIVE\n\nÉlément : "${name}"\n\nMot de passe requis :`);
        if (!pass) return false;
        form.querySelector('.pass-field').value = pass;
        showLoader();
        return true;
    }

    function openUpdate(file) {
        document.getElementById("upd_file").value = file;
        document.getElementById("upd_url").value = "";
        document.getElementById("overlay").style.display = "block";
        document.getElementById("update-modal").style.display = "block";
    }

    function closeModal() {
        document.getElementById("overlay").style.display = "none";
        document.getElementById("update-modal").style.display = "none";
    }

    function openCreatePopup(form) {
        createForm = form;
        document.getElementById("overlay-create").style.display = "block";
        document.getElementById("create-modal").style.display = "block";
        return false;
    }

    function closeCreatePopup() {
        document.getElementById("overlay-create").style.display = "none";
        document.getElementById("create-modal").style.display = "none";
    }

    function validateCreate() {
        const pass = document.getElementById("create-pass").value.trim();
        if (!pass) return;

        createForm.querySelector(".pass-field").value = pass;
        closeCreatePopup();
        showLoader();
        createForm.submit();
    }

    function showToast(message) {
        const container = document.getElementById('toast-container');
        const toast = document.createElement('div');
        toast.className = 'toast';

        toast.innerHTML = `
            <div class="toast-icon">⚠️</div>
            <div>${message}</div>
            <div class="toast-close" onclick="closeToast(this.parentElement)">✖</div>
        `;

        container.appendChild(toast);
        setTimeout(() => closeToast(toast), 5000);
    }

    function closeToast(toast) {
        toast.style.animation = 'toast-out 0.25s forwards';
        setTimeout(() => toast.remove(), 250);
    }

    window.addEventListener('load', () => {
        hideLoader();
    });

    <?php foreach ($errorMessages as $err): ?>
        showToast("<?= htmlspecialchars($err, ENT_QUOTES, 'UTF-8') ?>");
    <?php endforeach; ?>

    <?php foreach ($infoMessages as $msg): ?>
        showToast("<?= htmlspecialchars($msg, ENT_QUOTES, 'UTF-8') ?>");
    <?php endforeach; ?>
    </script>
</body>
</html>
