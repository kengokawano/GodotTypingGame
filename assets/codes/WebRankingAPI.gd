# WebRankingAPI.gd
# Web版専用のランキングAPI通信クラス
extends Node

signal rankings_loaded(data)
signal score_submitted(success)

var api_base_url: String = "https://orange.saitama.jp/type/apps/typing/api"

func load_rankings():
	if OS.has_feature("web"):
		var js_code = """
		fetch('%s/get_rankings.php')
			.then(response => response.json())
			.then(data => {
				godotRankingsLoaded(JSON.stringify(data));
			})
			.catch(error => {
				console.error('Failed to load rankings:', error);
				godotRankingsLoaded(null);
			});
		""" % api_base_url
		JavaScriptBridge.eval(js_code)
	else:
		rankings_loaded.emit(null)

func submit_score(player_name: String, score: int, mode: String):
	if OS.has_feature("web"):
		var data = {
			"name": player_name,
			"score": score,
			"mode": mode
		}
		var json_string = JSON.stringify(data)

		var js_code = """
		fetch('%s/submit_score.php', {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json'
			},
			body: '%s'
		})
			.then(response => response.json())
			.then(data => {
				godotScoreSubmitted(data.success);
			})
			.catch(error => {
				console.error('Failed to submit score:', error);
				godotScoreSubmitted(false);
			});
		""" % [api_base_url, json_string.replace("'", "\\'")]
		JavaScriptBridge.eval(js_code)
	else:
		score_submitted.emit(false)
