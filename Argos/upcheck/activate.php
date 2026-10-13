<?php
/**
 * Argos - API Activation
 * @Author : ROYJohan
 * @Version : 1.0.0
 * @Date : 2026-10-13
 * @Desc : Endpoint API pour activer le service Argos via une clé ou un hash d'identification
 */

header('Content-Type: application/json; charset=utf-8');

try {
    $fichierFunctions = __DIR__ . '/function.php';
    if (!file_exists($fichierFunctions)) {
        throw new Exception("Le fichier des fonctions et classes est introuvable.");
    }

    require_once $fichierFunctions;

    // Récupération des données entrantes (JSON, POST ou GET)
    $rawInput = file_get_contents('php://input');
    $inputData = json_decode($rawInput, true);

    if (empty($inputData) && !empty($_POST)) {
        $inputData = $_POST;
    }
    if (empty($inputData) && !empty($_GET)) {
        $inputData = $_GET;
    }

    if (!is_array($inputData)) {
        echo json_encode([
            'succes' => false,
            'message' => "Format de données invalide : JSON ou formulaire attendu."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }

    // Acceptation flexible de 'key' ou de 'hash_identification'[cite: 1]
    $hashIdentification = trim($inputData['key'] ?? $inputData['hash_identification'] ?? '');

    if (empty($hashIdentification)) {
        echo json_encode([
            'succes' => false,
            'message' => "Erreur de validation : Le paramètre 'key' est obligatoire pour l'activation."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }

    $argos = new UpCheck();
    $success = $argos->activate($hashIdentification);
    echo json_encode([
        'succes' => $success,
        'message' => $success ? "Service activé avec succès." : "Échec de l'activation : Clé invalide."
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    echo json_encode([
        'succes' => false,
        'message' => "Erreur critique serveur : " . $e->getMessage()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
