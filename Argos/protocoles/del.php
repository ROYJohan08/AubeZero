<?php
/**
 * Argos - API Suppression de Protocole
 * @Author : ROYJohan
 * @Version : 1.0.0
 * @Date : 2026-10-12
 * @Desc : Endpoint API REST sécurisé pour supprimer un protocole tactique Argos via un hash d'identification
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
        $inputData =$_POST;
    }
    if (empty($inputData) && !empty($_GET)) {
        $inputData =$_GET;
    }
    if (!is_array($inputData)) {
        http_response_code(400);
        echo json_encode([
            'succes' => false,
            'message' => "Format de données invalide : JSON ou formulaire attendu."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }
    $nom = trim($inputData['nom'] ?? '');
    $hashIdentification = trim($inputData['key'] ?? '');
    if (empty($nom) || empty($hashIdentification)) {
        http_response_code(400);
        echo json_encode([
            'succes' => false,
            'message' => "Erreur de validation : Les champs 'nom' et 'hash_identification' sont obligatoires pour la suppression."
        ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
        exit;
    }
    $manager = new Protocoles();
    $resultat =$manager->deleteProtocoles($nom,$hashIdentification);
    http_response_code($resultat['succes'] ? 200 : 400);
    echo json_encode($resultat, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'succes' => false,
        'message' => "Erreur critique serveur : " . $e->getMessage()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
