extends CanvasLayer

@onready var btn_start: Button = $VBoxContainer/HBoxContainer/btnStart
@onready var btn_debug_toggle: Button = $VBoxContainer/HBoxContainer/btnDebugToggle
@onready var btn_normal: CheckBox = $VBoxContainer/CenterContainer/ModeSelection/btnNormal
@onready var btn_time_attack: CheckBox = $VBoxContainer/CenterContainer/ModeSelection/btnTimeAttack
@onready var btn_se_enabled: CheckBox = $VBoxContainer/CenterContainer/ModeSelection/btnSEEnabled
@onready var debug_panel: Panel = $DebugPanel
@onready var ranking_panel: Panel = $RankingPanel
@onready var ranking_score_label: Label = $RankingPanel/ScoreLabel
@onready var ranking_name_input: LineEdit = $RankingPanel/NameInput
@onready var btn_ranking_register: Button = $RankingPanel/btnRankingRegister
@onready var btn_ranking_close: Button = $RankingPanel/btnRankingClose
@onready var normal_ranking_list: RichTextLabel = $RankingDisplay/NormalRanking/NormalList
@onready var time_attack_ranking_list: RichTextLabel = $RankingDisplay/TimeAttackRanking/TimeAttackList
@onready var start_id_input: LineEdit = $DebugPanel/StartIdInput
@onready var end_id_input: LineEdit = $DebugPanel/EndIdInput
@onready var btn_debug_start: Button = $DebugPanel/btnDebugStart
@onready var btn_debug_close: Button = $DebugPanel/btnDebugClose
@onready var la_score_label: Label = $VBoxContainer/laScore

# GameDataシングルトンへの参照（autoloadとして設定されている想定）
var GameData = null

# デバッグモード設定（インスペクターで変更可能）
@export var debug_default_start_id: int = 108    # デバッグ開始ID
@export var debug_default_end_id: int = 108      # デバッグ終了ID

# モード選択用ButtonGroup
var mode_button_group: ButtonGroup = ButtonGroup.new()

func _ready():
	# AutoloadされたGameDataを取得
	if has_node("/root/GameData"):
		GameData = get_node("/root/GameData")
	
	# ノード参照の確認とデバッグ出力
	print("ControlUI Debug Info:")
	print("btn_start: ", btn_start)
	print("btn_debug_toggle: ", btn_debug_toggle)
	print("btn_debug_start: ", btn_debug_start)
	print("btn_debug_close: ", btn_debug_close)
	print("start_id_input: ", start_id_input)
	print("end_id_input: ", end_id_input)

	if btn_start:
		btn_start.pressed.connect(on_start_button_pressed)
	if btn_debug_toggle:
		btn_debug_toggle.pressed.connect(on_debug_toggle_pressed)
	if btn_debug_start:
		btn_debug_start.pressed.connect(on_debug_start_pressed)
	if btn_debug_close:
		btn_debug_close.pressed.connect(on_debug_close_pressed)
	
	# モード選択ボタンの設定
	if btn_normal and btn_time_attack:
		btn_normal.button_group = mode_button_group
		btn_time_attack.button_group = mode_button_group
		btn_normal.button_pressed = true  # デフォルトでNormalを選択
		btn_normal.toggled.connect(on_mode_selected)
		btn_time_attack.toggled.connect(on_mode_selected)
	
	if btn_se_enabled:
		btn_se_enabled.toggled.connect(on_se_toggled)
	if btn_ranking_register:
		btn_ranking_register.pressed.connect(on_ranking_register_pressed)
	if btn_ranking_close:
		btn_ranking_close.pressed.connect(on_ranking_close_pressed)
	
	# ボタンテキストをリセット（Loading状態から復帰）
	if btn_start:
		btn_start.text = "Start"
		btn_start.disabled = false
	if btn_debug_start:
		btn_debug_start.text = "Debug Start"
		btn_debug_start.disabled = false

	if GameData and GameData.has_valid_score():
		var score = GameData.get_score()
		if GameData.is_time_score():
			la_score_label.text = "クリアタイム: %s秒" % score
		else:
			la_score_label.text = "あなたのスコア: %s" % score
		# ランキング登録処理後にクリア（check_ranking_eligibilityの後）
	
	
	# デバッグパネルのデフォルト値を設定
	if start_id_input:
		start_id_input.text = str(debug_default_start_id)
		start_id_input.text_changed.connect(on_start_id_changed)
		print("StartIdInput editable: ", start_id_input.editable)
	if end_id_input:
		end_id_input.text = str(debug_default_end_id)
		end_id_input.text_changed.connect(on_end_id_changed)
		print("EndIdInput editable: ", end_id_input.editable)
	
	# SE設定の初期化
	if GameData and btn_se_enabled:
		btn_se_enabled.button_pressed = GameData.is_se_enabled()
		update_se_button_text()
	
	# ランキング表示の初期化
	update_ranking_display()
	
	# ランキング登録チェック
	check_ranking_eligibility()
	
	# ランキング処理完了後にスコアをクリア
	if GameData and GameData.has_valid_score() and not GameData.is_eligible_for_ranking():
		GameData.clear_score()

func on_start_button_pressed():
	print("Start button pressed!")
	# 選択されたモードとSE設定をGameDataに保存
	if GameData and btn_normal and btn_time_attack and btn_se_enabled:
		if btn_normal.button_pressed:
			GameData.set_game_mode(GameData.GameMode.NORMAL)
		elif btn_time_attack.button_pressed:
			GameData.set_game_mode(GameData.GameMode.TIME_ATTACK)
		GameData.set_se_enabled(btn_se_enabled.button_pressed)
	
	if btn_start:
		btn_start.text = "Loading..."
	get_tree().change_scene_to_file("res://assets/scenes/Main.tscn")

func on_debug_toggle_pressed():
	print("Debug toggle pressed!")
	if debug_panel:
		debug_panel.visible = not debug_panel.visible
		# デバッグパネルを開いた時にStartIdInputにフォーカスを設定
		if debug_panel.visible and start_id_input:
			start_id_input.grab_focus()
			start_id_input.select_all()

func on_debug_start_pressed():
	print("Debug start pressed!")
	if not start_id_input or not end_id_input:
		printerr("Debug input fields not found")
		return
		
	var start_text = start_id_input.text
	var end_text = end_id_input.text

	if start_text.is_valid_int() and end_text.is_valid_int():
		var start_id = start_text.to_int()
		var end_id = end_text.to_int()

		if start_id <= end_id:
			if GameData:
				GameData.set_debug_mode(start_id, end_id)
			if btn_debug_start:
				btn_debug_start.text = "Loading..."
			get_tree().change_scene_to_file("res://assets/scenes/Main.tscn")
		else:
			printerr("Start ID must be less than or equal to End ID")
	else:
		printerr("Please enter valid numbers for Start ID and End ID")

func on_debug_close_pressed():
	print("Debug close pressed!")
	if debug_panel:
		debug_panel.visible = false

func on_mode_selected(_button_pressed: bool):
	# ボタンが押された時の処理（必要に応じて追加）
	pass

func on_se_toggled(_button_pressed: bool):
	update_se_button_text()

func update_se_button_text():
	if btn_se_enabled:
		if btn_se_enabled.button_pressed:
			btn_se_enabled.text = "SE: ON"
		else:
			btn_se_enabled.text = "SE: OFF"

func check_ranking_eligibility():
	if GameData and GameData.is_eligible_for_ranking():
		show_ranking_registration()

func show_ranking_registration():
	if not GameData:
		return
	
	var score = GameData.get_score()
	var mode_text = "TIME ATTACK" if GameData.is_time_score() else "NORMAL"
	var score_text = "%s秒" % score if GameData.is_time_score() else str(score)
	
	ranking_score_label.text = "%s - スコア: %s" % [mode_text, score_text]
	ranking_name_input.text = ""
	ranking_panel.visible = true
	ranking_name_input.grab_focus()

func on_ranking_register_pressed():
	var player_name = ranking_name_input.text.strip_edges()
	if player_name.is_empty():
		return
	
	if GameData and GameData.add_to_ranking(player_name):
		var score = GameData.get_score()
		var is_time = GameData.is_time_score()
		
		ranking_panel.visible = false
		update_ranking_display()
		
		# 成功メッセージを表示
		if is_time:
			la_score_label.text = "ランキング登録成功！クリアタイム: %s秒" % score
		else:
			la_score_label.text = "ランキング登録成功！スコア: %s" % score
		
		# ランキング登録後にスコアクリア
		GameData.clear_score()

func on_ranking_close_pressed():
	ranking_panel.visible = false
	# ランキング登録を閉じた場合もスコアクリア
	if GameData:
		GameData.clear_score()

func on_start_id_changed(new_text: String):
	print("Start ID changed to: ", new_text)

func on_end_id_changed(new_text: String):
	print("End ID changed to: ", new_text)

func update_ranking_display():
	if not GameData or not GameData.ranking_manager:
		normal_ranking_list.text = "データなし"
		time_attack_ranking_list.text = "データなし"
		return
	
	# Normalランキング表示
	var normal_rankings = GameData.ranking_manager.get_normal_rankings()
	var normal_text = ""
	if normal_rankings.is_empty():
		normal_text = "記録なし"
	else:
		for i in range(normal_rankings.size()):
			var entry = normal_rankings[i]
			normal_text += "%d. %s - %s\n" % [i + 1, entry.name, entry.score]
	normal_ranking_list.text = normal_text
	
	# TimeAttackランキング表示
	var time_attack_rankings = GameData.ranking_manager.get_time_attack_rankings()
	var time_attack_text = ""
	if time_attack_rankings.is_empty():
		time_attack_text = "記録なし"
	else:
		for i in range(time_attack_rankings.size()):
			var entry = time_attack_rankings[i]
			time_attack_text += "%d. %s - %s秒\n" % [i + 1, entry.name, entry.score]
	time_attack_ranking_list.text = time_attack_text
