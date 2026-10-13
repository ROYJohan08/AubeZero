<?php
/**
 * Argos - API Check & Heartbeat
 * @Author : ROYJohan
 * @Version : 1.1.0
 * @Date : 2026-10-13
 * @Desc : Endpoint de déclenchement de la vérification UpCheck avec journalisation Argos et réponse JSON
 */

header('Content-Type: application/json; charset=utf-8');

try {
    $fichierFunctions = __DIR__ . '/function.php';
    if (!file_exists($fichierFunctions)) {
        throw new Exception("Le fichier des fonctions et classes est introuvable.");
    }
    
    require_once $fichierFunctions;

    // Initialisation et exécution du processus de surveillance
    $argos = new UpCheck();
    $argos->UpCheck();

    // Lecture de l'état mis à jour pour confirmation dans la réponse JSON
    $currentState = method_exists($argos, 'readState') ? $argos->readState() : [];

    http_response_code(200);
    echo json_encode([
        'succes' => true,
        'message' => "Processus de vérification exécuté avec succès.",
        'etat_actuel' => $currentState
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'succes' => false,
        'message' => "Erreur critique serveur lors du check : " . $e->getMessage()
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
}
