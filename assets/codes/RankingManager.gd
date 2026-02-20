# RankingManager.gd
extends Node

enum GameMode { NORMAL, TIME_ATTACK }

const MAX_RANKING_ENTRIES = 10

# API設定（インスペクターで変更可能）
@export var api_base_url: String = "https://orange.saitama.jp/type/apps/typing/api"
@export var enable_api: bool = true  # falseにするとローカルファイル保存

# HTTPリクエスト用ノード
var _http_get: HTTPRequest
var _http_post: HTTPRequest

# ランキングデータ構造
var _normal_rankings: Array = []      # Normalモード (スコア降順)
var _time_attack_rankings: Array = [] # TimeAttackモード (時間昇順)

# ローディング状態
var _is_loading: bool = false
var _load_complete: bool = false
var _is_submitting: bool = false
var _submit_complete: bool = false

func _ready():
	# HTTPRequestノードを作成
	_http_get = HTTPRequest.new()
	_http_post = HTTPRequest.new()
	add_child(_http_get)
	add_child(_http_post)

	# GZIP圧縮を無効化（圧縮処理のエラーを回避）
	_http_get.accept_gzip = false
	_http_post.accept_gzip = false

	# タイムアウトを設定
	_http_get.timeout = 10.0
	_http_post.timeout = 10.0

	_http_get.request_completed.connect(_on_get_rankings_completed)
	_http_post.request_completed.connect(_on_submit_score_completed)

	# 読み込み開始（awaitしない - バックグラウンドで実行）
	load_rankings()

func wait_for_load_complete(max_wait: float = 5.0):
	var waited = 0.0
	while _is_loading and waited < max_wait:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	if _is_loading:
		print("Ranking load timed out, proceeding without data")
		_is_loading = false

func load_rankings():
	_is_loading = true
	if enable_api:
		# APIから読み込み
		await load_rankings_from_api()
	else:
		# ローカルファイルから読み込み（従来の方式）
		load_rankings_from_local()
		_is_loading = false
		_load_complete = true

func load_rankings_from_api():
	var url = api_base_url + "/get_rankings.php"
	print("=== ATTEMPTING API LOAD ===")
	print("URL: ", url)

	# HTTPS証明書検証を無効化（本番では有効化推奨）
	_http_get.set_tls_options(TLSOptions.client_unsafe())

	var error = _http_get.request(url)
	print("HTTP Request error code: ", error)

	if error != OK:
		printerr("!!! Failed to send HTTP request, error code: ", error)
		printerr("!!! Falling back to local file...")
		_is_loading = false
		_load_complete = true
		# フォールバック: ローカルから読み込み
		load_rankings_from_local()

func _on_get_rankings_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print("=== API RESPONSE RECEIVED ===")
	print("Result code: ", result)
	print("HTTP Response code: ", response_code)

	_is_loading = false
	_load_complete = true

	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("!!! HTTP Request failed, result: ", result)
		printerr("!!! Falling back to local file...")
		load_rankings_from_local()  # フォールバック
		return

	if response_code != 200:
		printerr("!!! HTTP Response code: ", response_code)
		var body_text = body.get_string_from_utf8()
		printerr("!!! Response body: ", body_text)
		printerr("!!! Falling back to local file...")
		load_rankings_from_local()  # フォールバック
		return

	var json_string = body.get_string_from_utf8()
	print("Response body: ", json_string)
	var json = JSON.new()
	var error = json.parse(json_string)

	if error == OK:
		var data = json.get_data()
		if data is Dictionary:
			_normal_rankings = data.get("normal", [])
			_time_attack_rankings = data.get("time_attack", [])
			validate_and_fix_rankings()
			print("✓ Rankings loaded successfully from API!")
			print("Normal rankings: ", _normal_rankings.size())
			print("Time attack rankings: ", _time_attack_rankings.size())
			return

	printerr("!!! Failed to parse rankings JSON from API")
	printerr("!!! Falling back to local file...")
	load_rankings_from_local()  # フォールバック

func load_rankings_from_local():
	var save_path = "user://data/ranking.json"

	if FileAccess.file_exists(save_path):
		print("Loading rankings from local file: ", save_path)
		var json_string = FileAccess.get_file_as_string(save_path)
		var json = JSON.new()
		var error = json.parse(json_string)

		if error == OK:
			var data = json.get_data()
			if data is Dictionary:
				_normal_rankings = data.get("normal", [])
				_time_attack_rankings = data.get("time_attack", [])
				validate_and_fix_rankings()
				return

	print("No local ranking file found, creating default")
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
	var dir_path = "user://data"
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			print("Failed to create directory: ", dir_path)
			return

	var file = FileAccess.open("user://data/ranking.json", FileAccess.WRITE)
	if file:
		var data = {
			"normal": _normal_rankings,
			"time_attack": _time_attack_rankings
		}
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()
	else:
		print("Failed to open file for writing: user://data/ranking.json")

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

	if enable_api:
		# APIに送信して完了を待つ
		await submit_score_to_api(player_name, score, mode)
		# HTTP通信完了を待つ
		while _is_submitting:
			await get_tree().create_timer(0.1).timeout
	else:
		# ローカルに保存（従来の方式）
		add_ranking_entry_local(player_name, score, mode)

	return true

func submit_score_to_api(player_name: String, score: int, mode: GameMode):
	_is_submitting = true
	_submit_complete = false

	var url = api_base_url + "/submit_score.php"
	var mode_string = "normal" if mode == GameMode.NORMAL else "time_attack"

	var data = {
		"name": player_name.strip_edges(),
		"score": score,
		"mode": mode_string
	}

	var json_string = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]

	print("=== SUBMITTING SCORE TO API ===")
	print("URL: ", url)
	print("Data: ", json_string)

	# HTTPS証明書検証を無効化（本番では有効化推奨）
	_http_post.set_tls_options(TLSOptions.client_unsafe())

	var error = _http_post.request(url, headers, HTTPClient.METHOD_POST, json_string)
	print("HTTP POST error code: ", error)

	if error != OK:
		printerr("!!! Failed to send score to API, error code: ", error)
		printerr("!!! Falling back to local storage...")
		_is_submitting = false
		# フォールバック: ローカルに保存
		add_ranking_entry_local(player_name, score, mode)

func _on_submit_score_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Submit score HTTP request failed: ", result)
		_is_submitting = false
		return

	if response_code != 200:
		printerr("Submit score HTTP response code: ", response_code)
		_is_submitting = false
		return

	var json_string = body.get_string_from_utf8()
	var json = JSON.new()
	var error = json.parse(json_string)

	if error == OK:
		var data = json.get_data()
		if data is Dictionary and data.get("success", false):
			print("Score submitted successfully to API")
			# APIから最新のランキングを再取得
			_is_loading = true  # 読み込み開始フラグを立てる
			await load_rankings_from_api()
			# 読み込み完了を待つ
			while _is_loading:
				await get_tree().create_timer(0.1).timeout
			_is_submitting = false
			_submit_complete = true
		else:
			printerr("API returned success=false")
			_is_submitting = false
	else:
		printerr("Failed to parse submit response")
		_is_submitting = false

func add_ranking_entry_local(player_name: String, score: int, mode: GameMode):
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
