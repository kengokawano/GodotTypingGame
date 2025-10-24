<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *'); // Allow requests from any origin

$rankingFile = 'rankings.json';

if (file_exists($rankingFile)) {
    // Read the file and output its content
    echo file_get_contents($rankingFile);
} else {
    // If the file doesn't exist, return an empty ranking structure
    http_response_code(404);
    echo json_encode(['error' => 'Ranking file not found.']);
}
?>
