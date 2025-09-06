extends CanvasLayer

@onready var btn_start: Button = $VBoxContainer/HBoxContainer/btnStart
@onready var btn_debug_toggle: Button = $VBoxContainer/HBoxContainer/btnDebugToggle
@onready var debug_panel: Panel = $DebugPanel
@onready var start_id_input: LineEdit = $DebugPanel/StartIdInput
@onready var end_id_input: LineEdit = $DebugPanel/EndIdInput
@onready var btn_debug_start: Button = $DebugPanel/btnDebugStart
@onready var btn_debug_close: Button = $DebugPanel/btnDebugClose
@onready var la_score_label: Label = $VBoxContainer/laScore

# GameDataシングルトンへの参照（autoloadとして設定されている想定）
var GameData = null

func _ready():
	# AutoloadされたGameDataを取得
	if has_node("/root/GameData"):
		GameData = get_node("/root/GameData")

	btn_start.pressed.connect(on_start_button_pressed)
	btn_debug_toggle.pressed.connect(on_debug_toggle_pressed)
	btn_debug_start.pressed.connect(on_debug_start_pressed)
	btn_debug_close.pressed.connect(on_debug_close_pressed)

	if GameData and GameData.has_valid_score():
		var score = GameData.get_score()
		la_score_label.text = "あなたのスコア: %s" % score
		GameData.clear_score()
	else:
		la_score_label.text = "スタートボタンを押してゲームを始めよう！"

func on_start_button_pressed():
	btn_start.text = "Loading..."
	get_tree().change_scene_to_file("res://assets/scense/Main.tscn")

func on_debug_toggle_pressed():
	debug_panel.visible = not debug_panel.visible

func on_debug_start_pressed():
	var start_text = start_id_input.text
	var end_text = end_id_input.text

	if start_text.is_valid_int() and end_text.is_valid_int():
		var start_id = start_text.to_int()
		var end_id = end_text.to_int()

		if start_id <= end_id:
			if GameData:
				GameData.set_debug_mode(start_id, end_id)
			btn_debug_start.text = "Loading..."
			get_tree().change_scene_to_file("res://assets/scense/Main.tscn")
		else:
			printerr("Start ID must be less than or equal to End ID")
	else:
		printerr("Please enter valid numbers for Start ID and End ID")

func on_debug_close_pressed():
	debug_panel.visible = false
