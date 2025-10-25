<?php
// GZIP圧縮を無効化（Godot Web版との互換性のため）
ini_set('zlib.output_compression', 'Off');
if (function_exists('apache_setenv')) {
    apache_setenv('no-gzip', '1');
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *'); // Allow requests from any origin
header('Content-Encoding: identity'); // 圧縮なし

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
