extends CanvasLayer

@onready var question_label: Label = $all/QuestionLabel
@onready var kana_progress_label: RichTextLabel = $all/KanaProgressLabel
@onready var kana_label: RichTextLabel = $all/KanaRitch
@onready var time_label: Label = $all/TimeLabel
@onready var combo_label: Label = $all/footer/ComboContainer/ComboLabel
@onready var combo_text_label: Label = $all/footer/ComboContainer/ComboTextLabel
@onready var combo_particles: CPUParticles2D = $all/footer/ComboContainer/ComboLabel/ComboParticles
@onready var combo_text_particles: CPUParticles2D = $all/footer/ComboContainer/ComboTextLabel/ComboTextParticles
@onready var score_label: Label = $all/header/ScoreContainer/ScoreLabel
@onready var mode_label: Label = $all/header/ModeLabel
@onready var game_timer: Timer = $GameTimer
@onready var player_animation: AnimatedSprite2D = $playerAnimation
@onready var correct_key_audio: AudioStreamPlayer = $CorrectKeyAudio

enum GameMode { NONE, NORMAL, TIME_ATTACK, DEBUG }

# UI色の設定（インスペクターで変更可能）
@export var color_completed: String = "#ff7f7f"  # 完了した文字の色
@export var color_current: String = "yellow"     # 現在の文字の色
@export var color_normal: String = "white"       # 通常の文字の色

# デバッグモード設定（インスペクターで変更可能）
@export var debug_default_start_id: int = 108    # デバッグ開始ID
@export var debug_default_end_id: int = 108      # デバッグ終了ID

# タイムアタックモード設定（インスペクターで変更可能）
@export var time_attack_question_count: int = 30  # タイムアタック問題数

# Normalモード設定（インスペクターで変更可能）
@export var normal_time_limit: int = 10  # Normal制限時間（秒）

# アニメーション設定（インスペクターで変更可能）
@export var available_animations: Array[String] = ["act1", "dash"]

var _current_mode = GameMode.NONE
var _remaining_time_in_seconds: int = 0
var _questions_completed: int = 0
var _is_game_started: bool = false
var _elapsed_time_in_seconds: int = 0
var _combo_count: int = 0
var _total_key_presses: int = 0

var _all_questions: Array = []
var _current_question_text: String = ""
var _current_kana: Array[String] = []
var _current_roman: Array[Array] = []
var _current_kana_index: int = 0
var _candidate_romans: Array = []
var _input_roman_index: int = 0

# デバッグモード用
var _debug_questions: Array = []
var _debug_start_id: int = 0
var _debug_end_id: int = 0
var _debug_current_index: int = 0

# シングルトンへの参照
var GameData = null
var RomanTypingParser = null
const QuestionLoader = preload("res://assets/codes/QuestionLoader.gd")

# アニメーション管理用
var _cached_animation_count: int = 0
var _animation_usage_count: Dictionary = {}  # 使用頻度追跡
var _preloaded_animations: Dictionary = {}  # プリロードされたアニメーション

func _ready():
	# Autoloadされたシングルトンを取得
	if has_node("/root/GameData"):
		GameData = get_node("/root/GameData")
	# RomanTypingParserは通常のノードとしてインスタンス化
	RomanTypingParser = get_node_or_null("RomanTypingParser")
	if RomanTypingParser == null:
		RomanTypingParser = preload("res://assets/codes/RomanTypingParser.gd").new()
		RomanTypingParser.name = "RomanTypingParser"
		add_child(RomanTypingParser)

	game_timer.timeout.connect(on_game_timer_timeout)
	RomanTypingParser.read_json_file()
	await load_questions()
	update_display()
	
	# アニメーション設定をキャッシュ
	validate_animations()
	_cached_animation_count = available_animations.size()

	if GameData and GameData.is_debug_mode:
		start_debug_from_game_data.call_deferred()
	elif GameData:
		var selected_mode = GameData.get_game_mode()
		if selected_mode == GameData.GameMode.NORMAL:
			start_normal.call_deferred()
		elif selected_mode == GameData.GameMode.TIME_ATTACK:
			start_time_attack.call_deferred()
		else:
			start_normal.call_deferred()  # フォールバック
	else:
		start_normal.call_deferred()  # GameDataがない場合のフォールバック

func _input(event: InputEvent):
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		# エスケープキーでタイトル画面に戻る（ゲーム中のみ）
		if event.keycode == KEY_ESCAPE and _is_game_started:
			return_to_title()
			return
	
	if not _is_game_started: return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.unicode != 0:
			var input_char = char(event.unicode)
			handle_key_press(input_char)
		else:
			# Handle special keys that don't have a unicode representation
			var key_string = OS.get_keycode_string(event.keycode).to_lower()
			if key_string in ["minus", "hyphen", "kp_subtract"]:
				handle_key_press("-")
			elif key_string in ["period", "kp_period"]:
				handle_key_press(".")
			elif key_string in ["slash", "kp_divide"]:
				handle_key_press("/")

func load_questions():
	_all_questions = await QuestionLoader.load_questions_from_file("res://assets/data/questions.json")
	if _all_questions.is_empty():
		var fallback_q = preload("res://assets/codes/Question.gd").new()
		fallback_q.id = 0
		fallback_q.text = "Fallback"
		fallback_q.kana = "あ"
		fallback_q.tags = ["fallback"]
		fallback_q.era = 2025
		_all_questions.append(fallback_q)

func start_normal():
	start_game(GameMode.NORMAL)

func start_time_attack():
	start_game(GameMode.TIME_ATTACK)

func start_debug_mode(start_id: int, end_id: int):
	_debug_start_id = start_id
	_debug_end_id = end_id
	_debug_current_index = 0

	_debug_questions = _all_questions.filter(func(q): return q.id >= start_id and q.id <= end_id)
	_debug_questions.sort_custom(func(a, b): return a.id < b.id)

	if _debug_questions.is_empty():
		printerr("No questions found in range %d-%d" % [start_id, end_id])
		return

	start_game(GameMode.DEBUG)

func start_debug_from_game_data():
	if GameData:
		start_debug_mode(GameData.debug_start_id, GameData.debug_end_id)
		GameData.clear_debug_mode()

func start_game(mode: GameMode):
	_current_mode = mode
	_is_game_started = true

	_combo_count = 0
	_total_key_presses = 0
	_current_kana_index = 0
	_input_roman_index = 0
	_candidate_romans = []

	if _current_mode == GameMode.NORMAL:
		_remaining_time_in_seconds = normal_time_limit
	elif _current_mode == GameMode.TIME_ATTACK:
		_elapsed_time_in_seconds = 0
		_questions_completed = 0
	elif _current_mode == GameMode.DEBUG:
		_elapsed_time_in_seconds = 0
		_questions_completed = 0

	load_next_question()
	game_timer.start()
	
	# プレイヤーアニメーション開始（ランダム選択）
	play_random_animation()

func load_next_question():
	_current_kana_index = 0
	_input_roman_index = 0
	_candidate_romans = []

	var question
	if _current_mode == GameMode.DEBUG:
		if _debug_current_index >= _debug_questions.size():
			finish_game()
			return
		question = _debug_questions[_debug_current_index]
	elif _current_mode == GameMode.TIME_ATTACK:
		if _questions_completed >= time_attack_question_count:
			finish_game()
			return
		var random_questions = QuestionLoader.get_random_questions(1)
		question = random_questions[0] if not random_questions.is_empty() else _all_questions.pick_random()
	else:
		var random_questions = QuestionLoader.get_random_questions(1)
		question = random_questions[0] if not random_questions.is_empty() else _all_questions.pick_random()

	_current_question_text = question.text
	var result = RomanTypingParser.construct_type_sentence(question.kana)
	_current_kana = result[0]
	_current_roman = result[1]
	update_display()

func finish_game():
	game_timer.stop()
	_is_game_started = false
	
	# プレイヤーアニメーション停止
	if player_animation:
		player_animation.stop()

	# アニメーション統計を更新
	preload_frequent_animations()
	
	# リソースクリーンアップ
	cleanup_resources()

	var final_score = _total_key_presses if _current_mode == GameMode.NORMAL else _elapsed_time_in_seconds
	var is_time_score = _current_mode == GameMode.TIME_ATTACK
	if GameData:
		GameData.set_score(final_score, is_time_score)
	get_tree().change_scene_to_file("res://assets/scenes/Control.tscn")

	_current_mode = GameMode.NONE

func return_to_title():
	game_timer.stop()
	_is_game_started = false
	
	# プレイヤーアニメーション停止
	if player_animation:
		player_animation.stop()

	# アニメーション統計を更新
	preload_frequent_animations()
	
	# リソースクリーンアップ
	cleanup_resources()

	# スコア保存せずにタイトル画面に戻る
	get_tree().change_scene_to_file("res://assets/scenes/Control.tscn")

	_current_mode = GameMode.NONE

func update_display():
	if not _is_game_started:
		question_label.text = "Typing Game"
		kana_progress_label.text = ""
		kana_label.text = "Press a button to start"
		time_label.text = ""
		combo_label.text = ""
		combo_text_label.visible = false
		score_label.text = ""
		mode_label.text = "READY"
		return

	question_label.text = _current_question_text

	var kana_progress_text = ""
	for i in range(_current_kana.size()):
		if i < _current_kana_index:
			kana_progress_text += "[color=%s]%s[/color]" % [color_completed, _current_kana[i]]
		elif i == _current_kana_index:
			kana_progress_text += "[color=%s][font_size=42][u]%s[/u][/font_size][/color]" % [color_current, _current_kana[i]]
		else:
			kana_progress_text += _current_kana[i]
	kana_progress_label.text = kana_progress_text

	var roman_text = ""
	if not _candidate_romans.is_empty() and _input_roman_index > 0:
		var formatted_candidates = []
		for r in _candidate_romans:
			var completed = r.substr(0, _input_roman_index)
			var next_char = r.substr(_input_roman_index, 1) if _input_roman_index < r.length() else ""
			var remaining = r.substr(_input_roman_index + 1) if _input_roman_index + 1 < r.length() else ""
			if not next_char.is_empty():
				formatted_candidates.append("[color=%s]%s[/color][color=%s][u]%s[/u][/color]%s" % [color_completed, completed, color_current, next_char, remaining])
			else:
				formatted_candidates.append("[color=%s]%s[/color]" % [color_completed, completed])
		roman_text = "   ".join(formatted_candidates)
	else:
		var all_romans = _current_roman[_current_kana_index] if _current_roman.size() > _current_kana_index else []
		var current_romans = []
		if all_romans.size() > 4:
			current_romans = all_romans.slice(0, 4)
			current_romans.append("...")
		else:
			current_romans = all_romans
		
		var formatted_romans = []
		for r in current_romans:
			if r == "...":
				formatted_romans.append("...")
			elif not r.is_empty():
				var first_char = r.substr(0, 1)
				var remaining = r.substr(1) if r.length() > 1 else ""
				formatted_romans.append("[color=%s][u]%s[/u][/color]%s" % [color_current, first_char, remaining])
			else:
				formatted_romans.append(r)
		
		# 1つずつ改行
		roman_text = "\n".join(formatted_romans)
	kana_label.text = roman_text

	# コンボが3以上の時だけ表示
	if _combo_count >= 3:
		combo_label.text = "%s" % _combo_count
		combo_text_label.visible = true
	else:
		combo_label.text = ""
		combo_text_label.visible = false

	if _current_mode == GameMode.NORMAL:
		time_label.text = "%s" % _remaining_time_in_seconds
		score_label.text = "%s" % _total_key_presses
		mode_label.text = "NORMAL"
	elif _current_mode == GameMode.TIME_ATTACK:
		time_label.text = "%s/%s" % [_questions_completed + 1, time_attack_question_count]
		score_label.text = "%s秒" % _elapsed_time_in_seconds
		mode_label.text = "TIME ATTACK"
	elif _current_mode == GameMode.DEBUG:
		var current_id = _debug_questions[_debug_current_index].id if _debug_current_index < _debug_questions.size() else -1
		time_label.text = "ID: %s" % current_id
		score_label.text = "%s/%s" % [_questions_completed, _debug_questions.size()]
		mode_label.text = "DEBUG (%s-%s)" % [_debug_start_id, _debug_end_id]

func handle_key_press(input_char: String):
	if input_char.is_empty(): return

	_total_key_presses += 1

	var all_romans = _current_roman[_current_kana_index] if _current_roman.size() > _current_kana_index else []

	if _input_roman_index == 0:
		_candidate_romans = []
		for r in all_romans:
			if r.begins_with(input_char):
				_candidate_romans.append(r)
		if not _candidate_romans.is_empty():
			_input_roman_index = 1
			# 正確なキー入力時に音声を再生
			if correct_key_audio and GameData and GameData.is_se_enabled():
				correct_key_audio.play()
		else:
			_combo_count = 0
	else:
		var next_candidates = _candidate_romans.filter(func(r): return r.length() > _input_roman_index and r[_input_roman_index] == input_char)
		
		if not next_candidates.is_empty():
			_candidate_romans = next_candidates
			_input_roman_index += 1
			# 正確なキー入力時に音声を再生
			if correct_key_audio and GameData and GameData.is_se_enabled():
				correct_key_audio.play()
		else:
			_input_roman_index = 0
			_candidate_romans = []
			_combo_count = 0
			handle_key_press(input_char)
			return

	var completed = false
	for r in _candidate_romans:
		if r.length() == _input_roman_index:
			completed = true
			break
			
	if completed:
		_current_kana_index += 1
		_input_roman_index = 0
		_candidate_romans = []
		_combo_count += 1
		
		# コンボパーティクルの発動チェック（3回以上から毎回）
		if _combo_count >= 3:
			trigger_combo_particles()

		if _current_kana_index >= _current_kana.size():
			if _current_mode == GameMode.TIME_ATTACK:
				_questions_completed += 1
			elif _current_mode == GameMode.DEBUG:
				_questions_completed += 1
				_debug_current_index += 1
			load_next_question()
			return

	update_display()


func trigger_combo_particles():
	# パステルカラー5種類
	var colors = [
		Color(1, 0.8, 0.9, 1),      # パステルピンク
		Color(0.8, 0.9, 1, 1),      # パステルブルー
		Color(0.9, 1, 0.8, 1),      # パステルグリーン
		Color(1, 0.9, 0.8, 1),      # パステルオレンジ
		Color(0.9, 0.8, 1, 1),      # パステルパープル
	]
	var selected_color = colors[randi() % colors.size()]
	
	# ComboLabelのパーティクル
	if combo_particles:
		combo_particles.color = selected_color
		combo_particles.emitting = true
		combo_particles.restart()
	
	# ComboTextLabelのパーティクル（同じ色）
	if combo_text_particles:
		combo_text_particles.color = selected_color
		combo_text_particles.emitting = true
		combo_text_particles.restart()

func validate_animations():
	if not player_animation:
		return
	
	var sprite_frames = player_animation.sprite_frames
	if not sprite_frames:
		return
	
	# 存在しないアニメーションを削除
	var valid_animations: Array[String] = []
	for anim_name in available_animations:
		if sprite_frames.has_animation(anim_name):
			valid_animations.append(anim_name)
		else:
			printerr("Animation '%s' not found in sprite frames" % anim_name)
	
	available_animations = valid_animations

func play_random_animation():
	if not player_animation or _cached_animation_count == 0:
		return
	
	var random_index = randi() % _cached_animation_count
	var selected_animation = available_animations[random_index]
	
	# 使用統計を記録
	_animation_usage_count[selected_animation] = _animation_usage_count.get(selected_animation, 0) + 1
	
	player_animation.play(selected_animation)

func preload_frequent_animations():
	# 使用頻度の高いアニメーションを事前準備（将来の拡張用）
	var sorted_animations = []
	for anim_name in _animation_usage_count.keys():
		sorted_animations.append([anim_name, _animation_usage_count[anim_name]])
	
	sorted_animations.sort_custom(func(a, b): return a[1] > b[1])
	
	# 上位のアニメーションをプリロード対象とマーク
	var preload_count = min(3, sorted_animations.size())
	for i in range(preload_count):
		var anim_name = sorted_animations[i][0]
		_preloaded_animations[anim_name] = true

func get_animation_stats() -> Dictionary:
	return _animation_usage_count.duplicate()

func cleanup_resources():
	# 使用されていない問題データをクリーンアップ
	_debug_questions.clear()
	
	# 大きなキャッシュサイズの場合、部分的にクリア
	if QuestionLoader._cached_questions_by_id.size() > 500:
		var keys_to_remove = []
		var count = 0
		for key in QuestionLoader._cached_questions_by_id.keys():
			if count > 250:  # 半分を残す
				keys_to_remove.append(key)
			count += 1
		
		for key in keys_to_remove:
			QuestionLoader._cached_questions_by_id.erase(key)
	
	# メモリ使用量をGCに委ねる
	if OS.has_method("force_gc"):
		OS.call("force_gc")

func get_memory_usage_info() -> Dictionary:
	return {
		"cached_questions": QuestionLoader._cached_questions_by_id.size(),
		"raw_data_loaded": QuestionLoader._cache_loaded,
		"animation_stats": _animation_usage_count.size(),
		"preloaded_animations": _preloaded_animations.size()
	}

func on_game_timer_timeout():
	if _current_mode == GameMode.TIME_ATTACK:
		_elapsed_time_in_seconds += 1
	elif _current_mode == GameMode.NORMAL:
		_remaining_time_in_seconds -= 1
		if _remaining_time_in_seconds <= 0:
			finish_game()
	update_display()
