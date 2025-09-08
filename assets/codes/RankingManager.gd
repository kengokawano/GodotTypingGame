# RankingManager.gd
extends Node

enum GameMode { NORMAL, TIME_ATTACK }

const RANKING_FILE_PATH = "ranking.json"
const MAX_RANKING_ENTRIES = 5

# ランキングデータ構造
var _normal_rankings: Array = []      # Normalモード (スコア降順)
var _time_attack_rankings: Array = [] # TimeAttackモード (時間昇順)

func _ready():
	await load_rankings()

func load_rankings():
	var res_path = "res://assets/data/ranking.json"
	
	if FileAccess.file_exists(res_path):
		print("Loading rankings from: ", res_path)
		var json_string = FileAccess.get_file_as_string(res_path)
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			var data = json.get_data()
			if data is Dictionary:
				_normal_rankings = data.get("normal", [])
				_time_attack_rankings = data.get("time_attack", [])
				validate_and_fix_rankings()
				return
	
	print("No ranking file found, creating default")
	create_default_ranking_file()

func create_default_ranking_file():
	_normal_rankings = []
	_time_attack_rankings = []
	save_rankings()

func validate_and_fix_rankings():
	# 各ランキングの整合性をチェック
	_normal_rankings = validate_ranking_array(_normal_rankings, false)
	_time_attack_rankings = validate_ranking_array(_time_attack_rankings, true)

func validate_ranking_array(rankings: Array, is_time_based: bool) -> Array:
	var valid_rankings = []
	
	for entry in rankings:
		if entry is Dictionary and entry.has("name") and entry.has("score"):
			var player_name = str(entry.get("name", "")).strip_edges()
			var score = entry.get("score", 0)
			
			if player_name.length() > 0 and score > 0:
				valid_rankings.append({
					"name": player_name,
					"score": score,
					"timestamp": entry.get("timestamp", Time.get_unix_time_from_system())
				})
	
	# ソート（Normalは降順、TimeAttackは昇順）
	if is_time_based:
		valid_rankings.sort_custom(func(a, b): return a.score < b.score)
	else:
		valid_rankings.sort_custom(func(a, b): return a.score > b.score)
	
	# 上位5位まで
	if valid_rankings.size() > MAX_RANKING_ENTRIES:
		valid_rankings = valid_rankings.slice(0, MAX_RANKING_ENTRIES)
	
	return valid_rankings

func save_rankings():
	print("Note: Ranking save is disabled for HTTP mode")

func is_score_rankable(score: int, mode: GameMode) -> bool:
	var rankings = _normal_rankings if mode == GameMode.NORMAL else _time_attack_rankings
	
	# 5位未満なら必ずランクイン
	if rankings.size() < MAX_RANKING_ENTRIES:
		return true
	
	# 5位のスコアと比較
	var worst_score = rankings[-1].score
	if mode == GameMode.NORMAL:
		return score > worst_score  # より高いスコア
	else:
		return score < worst_score  # より短い時間

func add_ranking_entry(player_name: String, score: int, mode: GameMode) -> bool:
	if not is_score_rankable(score, mode):
		return false
	
	var entry = {
		"name": player_name.strip_edges(),
		"score": score,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	if mode == GameMode.NORMAL:
		_normal_rankings.append(entry)
		_normal_rankings.sort_custom(func(a, b): return a.score > b.score)
		if _normal_rankings.size() > MAX_RANKING_ENTRIES:
			_normal_rankings = _normal_rankings.slice(0, MAX_RANKING_ENTRIES)
	else:
		_time_attack_rankings.append(entry)
		_time_attack_rankings.sort_custom(func(a, b): return a.score < b.score)
		if _time_attack_rankings.size() > MAX_RANKING_ENTRIES:
			_time_attack_rankings = _time_attack_rankings.slice(0, MAX_RANKING_ENTRIES)
	
	save_rankings()
	return true

func get_normal_rankings() -> Array:
	return _normal_rankings.duplicate(true)

func get_time_attack_rankings() -> Array:
	return _time_attack_rankings.duplicate(true)

func get_ranking_position(score: int, mode: GameMode) -> int:
	var rankings = _normal_rankings if mode == GameMode.NORMAL else _time_attack_rankings
	
	if mode == GameMode.NORMAL:
		for i in range(rankings.size()):
			if score > rankings[i].score:
				return i + 1
	else:
		for i in range(rankings.size()):
			if score < rankings[i].score:
				return i + 1
	
	# 最下位または圏外
	return rankings.size() + 1

func clear_all_rankings():
	_normal_rankings.clear()
	_time_attack_rankings.clear()
	save_rankings()
