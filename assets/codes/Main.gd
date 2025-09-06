extends CanvasLayer

@onready var question_label: Label = $all/QuestionLabel
@onready var kana_progress_label: RichTextLabel = $all/KanaProgressLabel
@onready var kana_label: RichTextLabel = $all/KanaRitch
@onready var time_label: Label = $all/TimeLabel
@onready var combo_label: Label = $all/footer/ComboContainer/ComboLabel
@onready var score_label: Label = $all/header/ScoreContainer/ScoreLabel
@onready var mode_label: Label = $all/header/ModeLabel
@onready var game_timer: Timer = $GameTimer

enum GameMode { NONE, TIME_ATTACK, QUEST, DEBUG }

# UI色の設定（インスペクターで変更可能）
@export var color_completed: String = "#ff7f7f"  # 完了した文字の色
@export var color_current: String = "yellow"     # 現在の文字の色
@export var color_normal: String = "white"       # 通常の文字の色

# デバッグモード設定（インスペクターで変更可能）
@export var debug_default_start_id: int = 108    # デバッグ開始ID
@export var debug_default_end_id: int = 108      # デバッグ終了ID


var _current_mode = GameMode.NONE
var _remaining_time_in_seconds: int = 0
var _questions_completed: int = 0
const TOTAL_QUEST_QUESTIONS = 5
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
	load_questions()
	update_display()

	if GameData and GameData.is_debug_mode:
		start_debug_from_game_data.call_deferred()
	else:
		start_time_attack.call_deferred()

func _input(event: InputEvent):
	print("_input called, _is_game_started: ", _is_game_started)
	if not _is_game_started: return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var input_char = OS.get_keycode_string(event.keycode).to_lower()
		if input_char in ["minus", "hyphen", "kp_subtract"]:
			input_char = "-"

		if input_char.length() == 1:
			handle_key_press(input_char)

func load_questions():
	_all_questions = QuestionLoader.load_questions_from_file("res://assets/data/questions.json")
	if _all_questions.is_empty():
		var fallback_q = preload("res://assets/codes/Question.gd").new()
		fallback_q.id = 0
		fallback_q.text = "Fallback"
		fallback_q.kana = "あ"
		fallback_q.tags = ["fallback"]
		fallback_q.era = 2025
		_all_questions.append(fallback_q)

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

	if _current_mode == GameMode.TIME_ATTACK:
		_remaining_time_in_seconds = 10
	elif _current_mode == GameMode.QUEST:
		_elapsed_time_in_seconds = 0
		_questions_completed = 0
	elif _current_mode == GameMode.DEBUG:
		_elapsed_time_in_seconds = 0
		_questions_completed = 0

	load_next_question()
	game_timer.start()

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
	else:
		question = _all_questions.pick_random()

	_current_question_text = question.text
	var result = RomanTypingParser.construct_type_sentence(question.kana)
	_current_kana = result[0]
	_current_roman = result[1]
	update_display()

func finish_game():
	game_timer.stop()
	_is_game_started = false

	var final_score = _total_key_presses if _current_mode == GameMode.TIME_ATTACK else _elapsed_time_in_seconds
	if GameData:
		GameData.set_score(final_score)
	get_tree().change_scene_to_file("res://assets/scense/Control.tscn")

	_current_mode = GameMode.NONE

func update_display():
	if not _is_game_started:
		question_label.text = "Typing Game"
		kana_progress_label.text = ""
		kana_label.text = "Press a button to start"
		time_label.text = ""
		combo_label.text = ""
		score_label.text = ""
		mode_label.text = "READY"
		return

	question_label.text = _current_question_text

	var kana_progress_text = ""
	for i in range(_current_kana.size()):
		if i < _current_kana_index:
			kana_progress_text += "[color=%s]%s[/color]" % [color_completed, _current_kana[i]]
		elif i == _current_kana_index:
			kana_progress_text += "[color=%s][font_size=42]%s[/font_size][/color]" % [color_current, _current_kana[i]]
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
				formatted_candidates.append("[color=%s]%s[/color][color=%s]%s[/color]%s" % [color_completed, completed, color_current, next_char, remaining])
			else:
				formatted_candidates.append("[color=%s]%s[/color]" % [color_completed, completed])
		roman_text = "   ".join(formatted_candidates)
	else:
		var current_romans = _current_roman[_current_kana_index] if _current_roman.size() > _current_kana_index else []
		var formatted_romans = []
		for r in current_romans:
			if not r.is_empty():
				var first_char = r.substr(0, 1)
				var remaining = r.substr(1) if r.length() > 1 else ""
				formatted_romans.append("[color=%s]%s[/color]%s" % [color_current, first_char, remaining])
			else:
				formatted_romans.append(r)
		
		# 2個ずつ横並びにして改行
		var result_lines = []
		for i in range(0, formatted_romans.size(), 2):
			var line = formatted_romans[i]
			if i + 1 < formatted_romans.size():
				line += "  " + formatted_romans[i + 1]  # 2個目があれば横に並べる
			result_lines.append(line)
		roman_text = "\n".join(result_lines)
	kana_label.text = roman_text
	print("Setting kana_label.text to: ", roman_text)

	combo_label.text = "%s" % _combo_count if _combo_count > 3 else ""

	if _current_mode == GameMode.QUEST:
		time_label.text = "%s秒経過" % _elapsed_time_in_seconds
		score_label.text = "Q: %s/%s" % [_questions_completed + 1, TOTAL_QUEST_QUESTIONS]
		mode_label.text = "QUEST"
	elif _current_mode == GameMode.TIME_ATTACK:
		time_label.text = "%s" % _remaining_time_in_seconds
		score_label.text = "%s" % _total_key_presses
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
		else:
			_combo_count = 0
	else:
		var next_candidates = _candidate_romans.filter(func(r): return r.length() > _input_roman_index and r[_input_roman_index] == input_char)
		
		if not next_candidates.is_empty():
			_candidate_romans = next_candidates
			_input_roman_index += 1
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

		if _current_kana_index >= _current_kana.size():
			if _current_mode == GameMode.QUEST:
				_questions_completed += 1
				if _questions_completed >= TOTAL_QUEST_QUESTIONS:
					finish_game()
					return
			elif _current_mode == GameMode.DEBUG:
				_questions_completed += 1
				_debug_current_index += 1
			load_next_question()
			return

	update_display()


func on_game_timer_timeout():
	if _current_mode == GameMode.QUEST:
		_elapsed_time_in_seconds += 1
	elif _current_mode == GameMode.TIME_ATTACK:
		_remaining_time_in_seconds -= 1
		if _remaining_time_in_seconds <= 0:
			finish_game()
	update_display()
