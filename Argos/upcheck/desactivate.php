<?php
/**
 * Argos - API Désactivation
 * @Author : ROYJohan
 * @Version : 1.1.1
 * @Date : 2026-10-13
 * @Desc : Endpoint API pour désactiver le service Argos via une clé ou un hash d'identification
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
        $inputData = [];
    }
    $hashIdentification = trim($inputData['key'] ?? $inputData['hash_identification'] ?? '');
    if (empty($hashIdentification)) {
         echo json_encode([
			'success'    => true,
			'is_up'      => false,
			'message' =>"Erreur de validation : Le paramètre 'key' est obligatoire pour la désactivation."
			], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }

    $argos = new UpCheck();
    $success = $argos->desactivate($hashIdentification);

    http_response_code($success ? 200 : 401);
    echo json_encode([
        'succes' => $success,
        'message' => $success ? "Service désactivé avec succès." : "Échec de la désactivation : Clé invalide."
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'succes' => false,
        'message' => "Erreur critique serveur : " . $e->getMessage()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
