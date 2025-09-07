# GameData.gd
extends Node

func _ready():
	# RankingManagerを作成
	ranking_manager = preload("res://assets/codes/RankingManager.gd").new()
	add_child(ranking_manager)

var last_score: int = 0
var has_score: bool = false
var is_clear_time_score: bool = false  # スコアがクリア時間かどうか

# デバッグモード用
var debug_start_id: int = 0
var debug_end_id: int = 0
var is_debug_mode: bool = false

# ゲームモード選択用
enum GameMode { NORMAL, TIME_ATTACK }
var selected_game_mode: GameMode = GameMode.NORMAL

# SE設定
var se_enabled: bool = true

# ランキング関連
var ranking_manager: Node = null
var is_ranking_eligible: bool = false

func set_score(score: int, is_time_based: bool = false):
	last_score = score
	has_score = true
	is_clear_time_score = is_time_based
	
	# ランキング資格をチェック
	if ranking_manager:
		var mode = ranking_manager.GameMode.TIME_ATTACK if is_time_based else ranking_manager.GameMode.NORMAL
		is_ranking_eligible = ranking_manager.is_score_rankable(score, mode)

func get_score() -> int:
	return last_score

func has_valid_score() -> bool:
	return has_score

func clear_score():
	has_score = false
	last_score = 0
	is_clear_time_score = false
	is_ranking_eligible = false

func is_time_score() -> bool:
	return is_clear_time_score

func set_debug_mode(start_id: int, end_id: int):
	debug_start_id = start_id
	debug_end_id = end_id
	is_debug_mode = true

func clear_debug_mode():
	is_debug_mode = false
	debug_start_id = 0
	debug_end_id = 0

func set_game_mode(mode: GameMode):
	selected_game_mode = mode

func get_game_mode() -> GameMode:
	return selected_game_mode

func set_se_enabled(enabled: bool):
	se_enabled = enabled

func is_se_enabled() -> bool:
	return se_enabled

func is_eligible_for_ranking() -> bool:
	return is_ranking_eligible

func add_to_ranking(player_name: String) -> bool:
	if not ranking_manager or not is_ranking_eligible:
		return false
	
	var mode = ranking_manager.GameMode.TIME_ATTACK if is_clear_time_score else ranking_manager.GameMode.NORMAL
	var success = ranking_manager.add_ranking_entry(player_name, last_score, mode)
	
	if success:
		is_ranking_eligible = false  # 一度登録したら再登録不可
	
	return success
