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
		# アニメーション用の設定（レイアウト確定後にピボットを設定）
		await get_tree().process_frame
		btn_start.pivot_offset = btn_start.size / 2
		btn_start.mouse_entered.connect(_on_btn_start_mouse_entered)
		btn_start.mouse_exited.connect(_on_btn_start_mouse_exited)
		_setup_button_style()
		_start_pulse_animation()
		_start_label_pulse()

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

	# ランキング読み込み完了を待ってから表示
	if GameData and GameData.ranking_manager:
		await GameData.ranking_manager.wait_for_load_complete()

	# ランキング表示の初期化
	update_ranking_display()

	# ランキング登録チェック
	check_ranking_eligibility()
	
	# ランキング処理完了後にスコアをクリア
	if GameData and GameData.has_valid_score() and not GameData.is_eligible_for_ranking():
		GameData.clear_score()
	
	# デバッグボタンを初期状態で非表示
	if btn_debug_toggle:
		btn_debug_toggle.visible = false

func on_start_button_pressed():
	print("Start button pressed!")
	
	# クリック時の演出
	if btn_start:
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(btn_start, "scale", Vector2(0.9, 0.9), 0.1)
		tween.tween_property(btn_start, "scale", Vector2(1.1, 1.1), 0.1)
		await tween.finished
	
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
	print("start_id_input: ", start_id_input)
	print("end_id_input: ", end_id_input)
	
	if not start_id_input or not end_id_input:
		printerr("Debug input fields not found")
		return
		
	var start_text = start_id_input.text
	var end_text = end_id_input.text
	print("Start text: '", start_text, "', End text: '", end_text, "'")

	if start_text.is_valid_int() and end_text.is_valid_int():
		var start_id = start_text.to_int()
		var end_id = end_text.to_int()
		print("Start ID: ", start_id, ", End ID: ", end_id)

		if start_id <= end_id:
			if GameData:
				print("Setting debug mode: ", start_id, " to ", end_id)
				GameData.set_debug_mode(start_id, end_id)
				print("GameData.is_debug_mode: ", GameData.is_debug_mode)
				print("GameData.debug_start_id: ", GameData.debug_start_id)
				print("GameData.debug_end_id: ", GameData.debug_end_id)
			else:
				printerr("GameData not found!")
			if btn_debug_start:
				btn_debug_start.text = "Loading..."
			get_tree().change_scene_to_file("res://assets/scenes/Main.tscn")
		else:
			printerr("Start ID must be less than or equal to End ID")
	else:
		printerr("Please enter valid numbers for Start ID and End ID: '", start_text, "' and '", end_text, "'")

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
	if not GameData or not ranking_panel:
		return
	
	var score = GameData.get_score()
	var mode_text = "TIME ATTACK" if GameData.is_time_score() else "NORMAL"
	var score_text = "%s秒" % score if GameData.is_time_score() else str(score)
	
	ranking_score_label.text = "%s - スコア: %s" % [mode_text, score_text]
	ranking_name_input.text = ""
	
	# パネル出現のアニメーション
	ranking_panel.visible = true
	ranking_panel.modulate.a = 0
	ranking_panel.scale = Vector2(0.8, 0.8)
	ranking_panel.pivot_offset = ranking_panel.size / 2
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(ranking_panel, "modulate:a", 1.0, 0.4)
	tween.tween_property(ranking_panel, "scale", Vector2(1.0, 1.0), 0.4)
	
	ranking_name_input.grab_focus()

func on_ranking_register_pressed():
	var player_name = ranking_name_input.text.strip_edges()
	if player_name.is_empty():
		return

	if GameData:
		var score = GameData.get_score()
		var is_time = GameData.is_time_score()

		# ボタンを無効化して連打防止
		if btn_ranking_register: btn_ranking_register.disabled = true

		# API通信を待つ
		var success = await GameData.add_to_ranking(player_name)

		if success:
			# 閉じるアニメーション
			var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(ranking_panel, "modulate:a", 0.0, 0.3)
			tween.tween_property(ranking_panel, "scale", Vector2(0.8, 0.8), 0.3)
			await tween.finished
			ranking_panel.visible = false
			ranking_panel.scale = Vector2.ONE
			ranking_panel.modulate.a = 1.0

			# API通信完了後に再描画
			update_ranking_display()

			# 成功メッセージを表示
			if is_time:
				la_score_label.text = "ランキング登録成功！クリアタイム: %s秒" % score
			else:
				la_score_label.text = "ランキング登録成功！スコア: %s" % score

			# ランキング登録後にスコアクリア
			GameData.clear_score()
		
		if btn_ranking_register: btn_ranking_register.disabled = false

func on_ranking_close_pressed():
	# 閉じるアニメーション
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(ranking_panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(ranking_panel, "scale", Vector2(0.8, 0.8), 0.3)
	await tween.finished
	
	ranking_panel.visible = false
	ranking_panel.scale = Vector2.ONE
	ranking_panel.modulate.a = 1.0
	
	# ランキング登録を閉じた場合もスコアクリア
	if GameData:
		GameData.clear_score()

func on_start_id_changed(new_text: String):
	print("Start ID changed to: ", new_text)

func on_end_id_changed(new_text: String):
	print("End ID changed to: ", new_text)

# --- UI Animations ---

func _on_btn_start_mouse_entered():
	if btn_start.disabled: return
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn_start, "scale", Vector2(1.1, 1.1), 0.2)

func _on_btn_start_mouse_exited():
	if btn_start.disabled: return
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn_start, "scale", Vector2(1.0, 1.0), 0.2)

func _start_pulse_animation():
	if not btn_start: return
	
	# 無限ループするパルスアニメーション
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn_start, "modulate:a", 0.7, 0.8)
	tween.tween_property(btn_start, "modulate:a", 1.0, 0.8)

func _start_label_pulse():
	if not la_score_label: return
	
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(la_score_label, "modulate:a", 0.5, 1.2)
	tween.tween_property(la_score_label, "modulate:a", 1.0, 1.2)

func _setup_button_style():
	if not btn_start: return
	
	# レッズカラーの定義
	var REDS_RED = Color(0.85, 0.0, 0.0)
	var REDS_DARK = Color(0.1, 0.1, 0.1)
	var REDS_WHITE = Color(1.0, 1.0, 1.0)
	
	# スタートボタン・登録ボタン用 (赤ベース)
	var style_red = StyleBoxFlat.new()
	style_red.bg_color = REDS_RED
	style_red.corner_radius_top_left = 12
	style_red.corner_radius_top_right = 12
	style_red.corner_radius_bottom_left = 12
	style_red.corner_radius_bottom_right = 12
	style_red.content_margin_left = 30
	style_red.content_margin_right = 30
	style_red.shadow_size = 6
	style_red.shadow_offset = Vector2(0, 4)
	
	var style_red_hover = style_red.duplicate()
	style_red_hover.bg_color = Color(1.0, 0.1, 0.1)
	style_red_hover.shadow_size = 10
	
	# スタートボタン適用
	btn_start.add_theme_stylebox_override("normal", style_red)
	btn_start.add_theme_stylebox_override("hover", style_red_hover)
	btn_start.add_theme_stylebox_override("pressed", style_red)
	btn_start.add_theme_stylebox_override("focus", style_red_hover)
	btn_start.add_theme_color_override("font_color", REDS_WHITE)

	# ランキングパネル
	if ranking_panel:
		var style_panel = StyleBoxFlat.new()
		style_panel.bg_color = Color(0.08, 0.08, 0.08, 0.95) # 深い黒
		style_panel.border_width_left = 3
		style_panel.border_width_top = 3
		style_panel.border_width_right = 3
		style_panel.border_width_bottom = 3
		style_panel.border_color = REDS_RED
		style_panel.corner_radius_top_left = 15
		style_panel.corner_radius_top_right = 15
		style_panel.corner_radius_bottom_left = 15
		style_panel.corner_radius_bottom_right = 15
		style_panel.shadow_size = 25
		ranking_panel.add_theme_stylebox_override("panel", style_panel)

	# ランキング登録ボタン適用
	if btn_ranking_register:
		btn_ranking_register.add_theme_stylebox_override("normal", style_red)
		btn_ranking_register.add_theme_stylebox_override("hover", style_red_hover)
		btn_ranking_register.add_theme_color_override("font_color", REDS_WHITE)
	
	# ランキング閉じるボタン (黒/赤枠)
	if btn_ranking_close:
		var style_close = style_red.duplicate()
		style_close.bg_color = REDS_DARK
		style_close.border_width_left = 2
		style_close.border_width_top = 2
		style_close.border_width_right = 2
		style_close.border_width_bottom = 2
		style_close.border_color = REDS_RED
		btn_ranking_close.add_theme_stylebox_override("normal", style_close)
		
		var style_close_hover = style_close.duplicate()
		style_close_hover.bg_color = Color(0.2, 0.2, 0.2)
		btn_ranking_close.add_theme_stylebox_override("hover", style_close_hover)
		btn_ranking_close.add_theme_color_override("font_color", REDS_WHITE)

func _input(event: InputEvent):
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		# Ctrl+Shift+Dでデバッグボタン表示
		if event.keycode == KEY_D and event.ctrl_pressed and event.shift_pressed:
			if btn_debug_toggle:
				btn_debug_toggle.visible = not btn_debug_toggle.visible
		elif event.keycode == KEY_SPACE:
			# ランキング入力中でなければスペースキーでゲーム開始
			if not ranking_panel.visible:
				on_start_button_pressed()

func update_ranking_display():
	if not GameData or not GameData.ranking_manager:
		if normal_ranking_list: normal_ranking_list.text = "データなし"
		if time_attack_ranking_list: time_attack_ranking_list.text = "データなし"
		return
	
	var update_list = func(rl: RichTextLabel, rankings: Array, is_time: bool):
		if not rl: return
		rl.bbcode_enabled = true
		rl.clear() # 既存のテキストをクリア
		
		if rankings.is_empty():
			rl.append_text("[center]記録なし[/center]")
			return
		
		for i in range(rankings.size()):
			var entry = rankings[i]
			var rank_num = i + 1
			var color_code = "#FFFFFF"
			var prefix = ""
			
			if rank_num == 1: 
				color_code = "#FFD700" # Gold
				prefix = "👑 "
			elif rank_num == 2: 
				color_code = "#C0C0C0" # Silver
				prefix = "🥈 "
			elif rank_num == 3: 
				color_code = "#CD7F32" # Bronze
				prefix = "🥉 "
			else:
				prefix = "%2d. " % rank_num
			
			var score_suffix = "秒" if is_time else ""
			var name_str = str(entry.name).left(10)
			
			# push/popメソッドを使用してBBCodeを構築（タグの閉じ忘れやミスを防ぐ）
			rl.push_color(Color(color_code))
			if rank_num == 1: rl.push_bold()
			rl.add_text("%s%-10s : %s%s" % [prefix, name_str, entry.score, score_suffix])
			if rank_num == 1: rl.pop()
			rl.pop()
			rl.newline()
	
	update_list.call(normal_ranking_list, GameData.ranking_manager.get_normal_rankings(), false)
	update_list.call(time_attack_ranking_list, GameData.ranking_manager.get_time_attack_rankings(), true)
