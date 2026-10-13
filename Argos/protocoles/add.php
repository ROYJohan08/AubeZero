<?php
/**
 * Argos - API Ajout de Protocole
 * @Author : ROYJohan
 * @Version : 1.4.0
 * @Date : 2026-10-12
 * @Desc : Endpoint API REST sécurisé pour l'enregistrement d'un protocole avec validation du format des coordonnées GPS
 */

header('Content-Type: application/json; charset=utf-8');
try {
    $fichierFunctions = __DIR__ . '/function.php';
    if (!file_exists($fichierFunctions)) {
        throw new Exception("Le fichier des fonctions et classes est introuvable.");
    }
    require_once $fichierFunctions;
    $rawInput = file_get_contents('php://input');
    $inputData = json_decode($rawInput, true);
    if (empty($inputData) && !empty($_POST)) {
        $inputData = $_POST;
    }
    if (empty($inputData) && !empty($_GET)) {
        $inputData = $_GET;
    }
    if (!is_array($inputData)) {
        http_response_code(400);
        echo json_encode([
            'succes' => false,
            'message' => "Format de données invalide : JSON attendu."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }
    $nom = trim($inputData['nom'] ?? '');
    $description = trim($inputData['description'] ?? '');
    $brutCoordonnees = $inputData['coordonnees'] ?? null;
    $key = trim($inputData['key'] ?? '');
    if (empty($nom) || empty($key)) {
        http_response_code(400);
        echo json_encode([
            'succes' => false,
            'message' => "Erreur de validation : Les champs 'nom' et 'key' sont obligatoires."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }
    $coordonneesArray = [];
    if (is_string($brutCoordonnees)) {
        $decodedCoords = json_decode($brutCoordonnees, true);
        if (json_last_error() === JSON_ERROR_NONE && is_array($decodedCoords)) {
            $coordonneesArray = $decodedCoords;
        } else {
            http_response_code(400);
            echo json_encode([
                'succes' => false,
                'message' => "Erreur de format : Le champ 'coordonnees' n'est pas un JSON valide."
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
            exit;
        }
    } elseif (is_array($brutCoordonnees)) {
        $coordonneesArray = $brutCoordonnees;
    } else {
        http_response_code(400);
        echo json_encode([
            'succes' => false,
            'message' => "Erreur de format : Le champ 'coordonnees' est requis et doit être au format JSON/Array."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }
    if (empty($coordonneesArray)) {
        http_response_code(400);
        echo json_encode([
            'succes' => false,
            'message' => "Erreur de validation : Le tableau des coordonnées ne peut pas être vide."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }
    foreach ($coordonneesArray as $point) {
        if (!is_array($point) || !isset($point['lat']) || (!isset($point['lon']) && !isset($point['lng']) && !isset($point['longitude']))) {
            http_response_code(400);
            echo json_encode([
                'succes' => false,
                'message' => "Erreur de format : Chaque point GPS doit contenir au minimum les clés 'lat' et 'lon' (ex: [{'lon': '123', 'lat': '123'}])."
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
            exit;
        }
    }
    $manager = new Protocoles();
    $resultat = $manager->addProtocoles($nom, $description, $coordonneesArray, $key);
    http_response_code($resultat['succes'] ? 200 : 400);
    echo json_encode($resultat, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'succes' => false,
        'message' => "Erreur critique serveur : " . $e->getMessage()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
