<?php
/**
 * Argos - API GET pour récupérer l'état du service
 */

// Indiquer au client que la réponse est au format JSON
header('Content-Type: application/json; charset=utf-8');

// Inclure la classe UpCheck (ajustez le chemin si nécessaire)
require_once __DIR__ . '/function.php';

try {
    // Instanciation de la classe
    $argos = new UpCheck();

    // Lecture de l'état depuis State.json via la méthode publique
    $state = $argos->readState();

    // Vérification si la clé is_up existe
    $isUp = isset($state['is_up']) ? $state['is_up'] : null;

    // Réponse JSON propre
    echo json_encode([
        'success'    => true,
        'is_up'      => $isUp,
        'http_code'  => $state['http_code'] ?? null,
        'last_check' => $state['last_check'] ?? null
    ], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

} catch (\Throwable $e) {
    // Gestion des erreurs en cas de problème critique
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error'   => "Erreur interne lors de la récupération de l'état."
    ]);
}
