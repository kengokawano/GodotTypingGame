<?php
// GZIP圧縮を無効化（Godot Web版との互換性のため）
ini_set('zlib.output_compression', 'Off');
if (function_exists('apache_setenv')) {
    apache_setenv('no-gzip', '1');
}

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *'); // Allow requests from any origin
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Encoding: identity'); // 圧縮なし

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] != 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method Not Allowed']);
    exit();
}

$rankingFile = 'rankings.json';
$maxEntries = 10;

// Get the posted data
$json_data = file_get_contents('php://input');
$data = json_decode($json_data, true);

// Validate input
if (!$data || !isset($data['name']) || !isset($data['score']) || !isset($data['mode'])) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid input']);
    exit();
}

$name = trim(strval($data['name']));
$score = intval($data['score']);
$mode = strval($data['mode']); // 'normal' or 'time_attack'

if (empty($name) || ($mode !== 'normal' && $mode !== 'time_attack')) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid data format']);
    exit();
}

// Open and lock the file
$fp = fopen($rankingFile, 'c+');
if (!$fp || !flock($fp, LOCK_EX)) {
    http_response_code(500);
    echo json_encode(['error' => 'Could not lock ranking file for writing']);
    exit();
}

// Read current rankings
$currentRankingsJson = stream_get_contents($fp);
$rankings = json_decode($currentRankingsJson, true);
if (!is_array($rankings) || !isset($rankings['normal']) || !isset($rankings['time_attack'])) {
    // If file is empty or corrupt, initialize it
    $rankings = ['normal' => [], 'time_attack' => []];
}

// Add new entry
$newEntry = [
    'name' => $name,
    'score' => $score,
    'timestamp' => time()
];

$targetRanking = &$rankings[$mode];

// Check if score is rankable
$isRankable = false;
if (count($targetRanking) < $maxEntries) {
    $isRankable = true;
} else {
    $worstScore = $targetRanking[$maxEntries - 1]['score'];
    if ($mode === 'normal') {
        $isRankable = $score > $worstScore;
    } else { // time_attack
        $isRankable = $score < $worstScore;
    }
}

if ($isRankable) {
    $targetRanking[] = $newEntry;

    // Sort the rankings
    if ($mode === 'normal') {
        // Higher score is better
        usort($targetRanking, function($a, $b) {
            return $b['score'] <=> $a['score'];
        });
    } else { // time_attack
        // Lower score (time) is better
        usort($targetRanking, function($a, $b) {
            return $a['score'] <=> $b['score'];
        });
    }

    // Trim to max entries
    $rankings[$mode] = array_slice($targetRanking, 0, $maxEntries);

    // Write back to the file
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, json_encode($rankings, JSON_PRETTY_PRINT));
}

// Unlock and close
fflush($fp);
flock($fp, LOCK_UN);
fclose($fp);

// Return success response
echo json_encode(['success' => true, 'is_rankable' => $isRankable]);

?>
