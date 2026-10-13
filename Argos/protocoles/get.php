<?php
/**
 * Argos - API GET Protocoles
 * @Author : ROYJohan
 * @Version : 1.3.0
 * @Date : 2026-10-12
 * @Desc : API REST de récupération des protocoles Argos au format JSON via la classe Protocoles
 */

// En-têtes pour forcer le retour en JSON UTF-8
header('Content-Type: application/json; charset=utf-8');

try {
    // Vérification de la présence du fichier de classes
    $fichierFunctions = __DIR__ . '/function.php';
    if (!file_exists($fichierFunctions)) {
        throw new Exception("Le fichier des fonctions et classes est introuvable.");
    }
    require_once $fichierFunctions;
    $manager = new Protocoles();
    $protocoles = $manager->chargerProtocoles();
    http_response_code(200);
    echo json_encode([
        'succes' => true,
        'total' => count($protocoles),
        'donnees' => $protocoles
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'succes' => false,
        'message' => $e->getMessage()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE); 
}
