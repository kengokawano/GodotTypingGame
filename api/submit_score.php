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

// 暴力的な名前・誹謗中傷などを弾く（サーバーサイド）
// 表記ゆれ回避を防ぐため、名前と禁止語の両方を同じルールで正規化してから照合する
function normalizeForNgCheck($s) {
    // 空白・句読点・記号・制御文字（ゼロ幅文字含む）を全て除去
    // 「ち ん こ」「し、ね」「し・ね」「し★ね」のような分断を防止
    $s = preg_replace('/[\p{Z}\p{P}\p{S}\p{C}]+/u', '', $s);
    // 全角英数字→半角、半角カナ→全角、濁点結合（「４ね」「ｼﾈ」対策）
    $s = mb_convert_kana($s, 'aKV', 'UTF-8');
    // カタカナ→ひらがな（「シネ」「ザコ」をひらがなに寄せて一本化）
    $s = mb_convert_kana($s, 'c', 'UTF-8');
    // 小書き母音・促音・長音を除去（「しぃね」「ざっこ」「しーね」対策）
    // ゃゅょは残す（「ちゃんこ」→「ちんこ」のような誤検知を避けるため）
    $s = strtr($s, [
        'ぁ' => '', 'ぃ' => '', 'ぅ' => '', 'ぇ' => '', 'ぉ' => '', 'っ' => '',
        'ゕ' => 'か', 'ゖ' => 'け', 'ヵ' => 'か', 'ヶ' => 'け',
        'ー' => '', 'ｰ' => '',
    ]);
    // 英字は小文字に統一
    return mb_strtolower($s, 'UTF-8');
}

$nameForCheck = normalizeForNgCheck($name);

// カタカナ表記は正規化でひらがなに寄るため、ひらがなで書けば両方に一致する（既存のカタカナ表記はそのまま残してある）
$forbiddenWords = ['死ね', '殺す', 'アホ', 'あほ', '馬鹿', 'ばか', 'バカ', 'かす', 'カス', 'ゴミ', 'ごみ', 'きもい', 'キモイ', 'うざい', 'ウザイ', 'ガイジ', '池沼', '氏ね', 'しね', 'シネ', 'コロス', 'ころす', 'うんこ', 'ウンコ', 'うんち', 'ウンチ', 'ｳﾝｺ', 'ｳﾝﾁ', 'unko', 'unchi',
    '雑魚', 'ざこ', 'ザコ', 'ざっこ', 'ザッコ', 'ｻﾞｺ',
    // 差別語
    'きちがい', 'キチガイ', '気違い', '気狂い', 'メクラ', 'つんぼ', 'ツンボ', 'びっこ', 'ビッコ', 'ちんば', 'カタワ', '土人', 'チョン', '支那', '部落', '白痴', '低能', '知恵遅れ', 'ちえおくれ', '奇形', 'ニガー', 'nigger', 'nigga', 'ジャップ',
    // 性器・性的な語
    'ちんこ', 'チンコ', 'ちんちん', 'チンチン', 'ちんぽ', 'チンポ', 'ちんぽこ', 'チンポコ', 'ぽこちん', 'ポコチン', 'ペニス', 'penis', 'きんたま', 'キンタマ', '金玉', 'ちんぴく',
    'まんこ', 'マンコ', 'おまんこ', 'オマンコ', 'ヴァギナ', 'ばぎな', 'vagina', 'クリトリス', 'くりとりす', 'われめ', 'ワレメ', 'まんげ', 'マンゲ', '陰毛',
    'おっぱい', 'オッパイ', 'ぱいおつ', 'パイオツ', 'ちくび', 'チクビ', '乳首', '巨乳', 'きょにゅう',
    '陰茎', '陰部', '性器', '勃起', 'ぼっき', 'ボッキ', '射精', 'しゃせい', 'オナニー', 'おなにー', '自慰', 'マスターベーション',
    '童貞', 'どうてい', '処女', 'しょじょ', 'パイズリ', 'ぱいずり', 'フェラ', 'ふぇら', 'クンニ', 'くんに', 'アナル', 'あなる', 'anal', 'dick', 'pussy', 'cock', 'boobs', 'tits',
    'セックス', 'sex', 'fuck', 'shit', 'bitch',
    // 数字スラング・隠語（「4ね」=死ね、「タヒ」=死 など）
    '4545', '114514', '893', '4んで', '56す', '072', '1919', 'いくいく', 'イクイク', 'ikuiku',
    '4ね', '4ネ', 'よんね', '市ね', '市ネ', 'タヒね', 'タヒネ', 'たひね', 'タヒんで', '5ろす', '5ろせ', 'ころせ', 'コロセ', '殺せ',
    // 罵倒語
    'クソ', 'くそ', '糞', 'kuso', 'クズ', 'くず', '屑', 'ブス', 'ぶす', '消えろ', 'きえろ', '殺害'];
foreach ($forbiddenWords as $word) {
    // 禁止語側も同じ正規化を通す（カタカナ→ひらがな等で表記が揺れても一致させる）
    $word = normalizeForNgCheck($word);
    if ($word === '') {
        continue;
    }
    if (mb_strpos($nameForCheck, $word) !== false) {
        // クライアントが本文を読めるよう200で返し、表示用メッセージもここで決める
        echo json_encode(['success' => false, 'message' => '不適切な言葉が含まれているため登録できません'], JSON_UNESCAPED_UNICODE);
        exit();
    }
}

// Open and lock the file
$fp = fopen($rankingFile, 'c+');
if (!$fp || !flock($fp, LOCK_EX)) {
    http_response_code(500);
    echo json_encode(['error' => 'Could not lock ranking file for writing']);
    exit();
}

// Read current rankings (ロック取得後にファイル先頭から読み直す)
rewind($fp);
$currentRankingsJson = stream_get_contents($fp);
$rankings = json_decode($currentRankingsJson, true);
if (!is_array($rankings) || !isset($rankings['normal']) || !isset($rankings['time_attack'])) {
    // ファイルにデータがあるのにパースできない場合はデータ破損
    // 既存データを保護するため書き込みを中止する
    $stat = fstat($fp);
    if ($stat !== false && $stat['size'] > 0) {
        flock($fp, LOCK_UN);
        fclose($fp);
        http_response_code(500);
        echo json_encode(['error' => 'Ranking data corrupt, aborting to protect existing data']);
        exit();
    }
    // ファイルが本当に空の場合のみ初期化
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
