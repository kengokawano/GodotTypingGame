# QuestionLoader.gd
extends Node

const QuestionResource = preload("res://assets/codes/Question.gd")

# キャッシュシステム
static var _cached_questions: Array = []
static var _cached_questions_by_id: Dictionary = {}
static var _raw_data_cache: Array = []
static var _cache_loaded: bool = false

# 遅延読み込み用の設定
@export var lazy_load_enabled: bool = true
@export var cache_size_limit: int = 500  # キャッシュする問題数の上限
@export var initial_load_limit: int = 50  # 初回読み込み問題数

static func load_questions_from_file(file_path: String) -> Array:
	if _cache_loaded and not _cached_questions.is_empty():
		return _cached_questions
	
	var json_string = ""
	


	if not FileAccess.file_exists(file_path):
		printerr("Failed to find question file: ", file_path)
		return []
	json_string = FileAccess.get_file_as_string(file_path)


	if json_string.is_empty():
		printerr("JSON string is empty")
		return []
	
	# JSONの先頭をチェックしてデバッグ情報を出力
	var preview = json_string.substr(0, min(100, json_string.length()))
	print("JSON preview (first 100 chars): ", preview)
	
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		var error_line = json.get_error_line()
		var error_message = json.get_error_message()
		printerr("Failed to parse questions JSON: ", error_message, " at line ", error_line)
		
		# エラー行周辺のテキストを表示
		if error_line > 0:
			var lines = json_string.split("\n")
			if error_line <= lines.size():
				var start_line = max(0, error_line - 3)
				var end_line = min(lines.size() - 1, error_line + 2)
				print("Context around error:")
				for i in range(start_line, end_line + 1):
					var marker = " -> " if i == error_line - 1 else "    "
					print(marker, "Line ", i + 1, ": ", lines[i])
		return []

	var data = json.get_data()
	if not data is Array:
		printerr("Invalid questions format, expected an array.")
		return []

	_raw_data_cache = data
	_cache_loaded = true
	
	# 初期ロード分の問題を作成（全体の一部のみ）
	var initial_load_count = min(data.size(), 20)  # 最初は20問まで
	_cached_questions = create_questions_from_raw_data(0, initial_load_count)
	
	return _cached_questions

static func create_questions_from_raw_data(start_index: int, count: int) -> Array:
	var questions: Array = []
	var end_index = min(start_index + count, _raw_data_cache.size())
	
	for i in range(start_index, end_index):
		var question_data = _raw_data_cache[i]
		if question_data is Dictionary:
			var q = QuestionResource.new()
			q.id = question_data.get("id", 0)
			q.No = question_data.get("No", "")
			q.Pos = question_data.get("Pos", "")
			q.text = question_data.get("text", "")
			q.kana = question_data.get("kana", "")
			q.tags = question_data.get("tags", [])
			q.era = question_data.get("era", 0)
			questions.append(q)
			_cached_questions_by_id[q.id] = q
	
	return questions

static func get_question_by_id(id: int) -> Resource:
	# キャッシュから探す
	if _cached_questions_by_id.has(id):
		return _cached_questions_by_id[id]
	
	# キャッシュにない場合、rawデータから探して作成
	for question_data in _raw_data_cache:
		if question_data is Dictionary and question_data.get("id", 0) == id:
			var q = QuestionResource.new()
			q.id = question_data.get("id", 0)
			q.No = question_data.get("No", "")
			q.Pos = question_data.get("Pos", "")
			q.text = question_data.get("text", "")
			q.kana = question_data.get("kana", "")
			q.tags = question_data.get("tags", [])
			q.era = question_data.get("era", 0)
			_cached_questions_by_id[id] = q
			return q
	
	return null

static func get_random_questions(count: int) -> Array:
	if _raw_data_cache.is_empty():
		return []
	
	# 全データからランダムに選択（キャッシュに関係なく）
	var available_indices = range(_raw_data_cache.size())
	available_indices.shuffle()
	
	var selected_questions: Array = []
	var selected_count = min(count, available_indices.size())
	
	for i in range(selected_count):
		var index = available_indices[i]
		var question_data = _raw_data_cache[index]
		var id = question_data.get("id", 0)
		
		# 直接作成（キャッシュを経由しない）
		var question = create_question_from_data(question_data)
		if question:
			selected_questions.append(question)
	
	return selected_questions

# 単一の問題データから問題オブジェクトを作成
static func create_question_from_data(question_data: Dictionary):
	if not question_data is Dictionary:
		return null
	
	var q = QuestionResource.new()
	q.id = question_data.get("id", 0)
	q.No = question_data.get("No", "")
	q.Pos = question_data.get("Pos", "")
	q.text = question_data.get("text", "")
	q.kana = question_data.get("kana", "")
	q.tags = question_data.get("tags", [])
	q.era = question_data.get("era", 0)
	return q

# No、Pos、Tag での抽出機能
static func get_questions_by_no(no: String) -> Array:
	var filtered_questions: Array = []
	for question_data in _raw_data_cache:
		if question_data is Dictionary and question_data.get("No", "") == no:
			var id = question_data.get("id", 0)
			var question = get_question_by_id(id)
			if question:
				filtered_questions.append(question)
	return filtered_questions

static func get_questions_by_pos(pos: String) -> Array:
	var filtered_questions: Array = []
	for question_data in _raw_data_cache:
		if question_data is Dictionary and question_data.get("Pos", "") == pos:
			var id = question_data.get("id", 0)
			var question = get_question_by_id(id)
			if question:
				filtered_questions.append(question)
	return filtered_questions

static func get_questions_by_tag(tag: String) -> Array:
	var filtered_questions: Array = []
	for question_data in _raw_data_cache:
		if question_data is Dictionary:
			var tags = question_data.get("tags", [])
			if tag in tags:
				var id = question_data.get("id", 0)
				var question = get_question_by_id(id)
				if question:
					filtered_questions.append(question)
	return filtered_questions

# 複数条件での抽出機能
static func get_questions_by_filters(no_filter: String = "", pos_filter: String = "", tag_filter: String = "") -> Array:
	var filtered_questions: Array = []
	for question_data in _raw_data_cache:
		if question_data is Dictionary:
			var matches = true
			
			# No でフィルタ
			if no_filter != "" and question_data.get("No", "") != no_filter:
				matches = false
			
			# Pos でフィルタ
			if matches and pos_filter != "" and question_data.get("Pos", "") != pos_filter:
				matches = false
			
			# Tag でフィルタ
			if matches and tag_filter != "":
				var tags = question_data.get("tags", [])
				if tag_filter not in tags:
					matches = false
			
			if matches:
				var id = question_data.get("id", 0)
				var question = get_question_by_id(id)
				if question:
					filtered_questions.append(question)
	
	return filtered_questions

static func clear_cache():
	_cached_questions.clear()
	_cached_questions_by_id.clear()
	_raw_data_cache.clear()
	_cache_loaded = false
