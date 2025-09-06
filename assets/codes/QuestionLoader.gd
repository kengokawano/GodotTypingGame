# QuestionLoader.gd
extends Node

const QuestionResource = preload("res://assets/codes/Question.gd")

static func load_questions_from_file(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		printerr("Failed to find question file: ", file_path)
		return []

	var json_string = FileAccess.get_file_as_string(file_path)

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		printerr("Failed to parse questions JSON: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		return []

	var data = json.get_data()
	if not data is Array:
		printerr("Invalid questions format, expected an array.")
		return []

	var questions: Array = []
	for question_data in data:
		if question_data is Dictionary:
			var q = QuestionResource.new()
			q.id = question_data.get("id", 0)
			q.text = question_data.get("text", "")
			q.kana = question_data.get("kana", "")
			q.tags = question_data.get("tags", [])
			q.era = question_data.get("era", 0)
			questions.append(q)
	
	return questions
