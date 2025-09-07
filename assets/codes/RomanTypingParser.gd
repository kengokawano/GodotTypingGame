# RomanTypingParser.gd
extends Node

var _mapping_dictionary: Dictionary = {}

func read_json_file():
    if not _mapping_dictionary.is_empty():
        return

    var file_path = "res://assets/codes/romanTypingParseDictionary.json"
    if not FileAccess.file_exists(file_path):
        printerr("Cannot find roman typing dictionary: ", file_path)
        return

    var json_string = FileAccess.get_file_as_string(file_path)
    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        printerr("Error parsing roman typing dictionary JSON.")
        return

    var json_data = json.get_data()
    if json_data is Array:
        for map_data in json_data:
            if map_data is Dictionary and map_data.has("Pattern") and map_data.has("TypePattern"):
                _mapping_dictionary[map_data["Pattern"]] = map_data["TypePattern"]

func construct_type_sentence(sentence_hiragana: String) -> Array:
    if _mapping_dictionary.is_empty():
        read_json_file()

    var idx = 0
    var judge: Array[Array] = []
    var parsed_str: Array[String] = []

    while idx < sentence_hiragana.length():
        var valid_type_list: Array

        var uni = sentence_hiragana.substr(idx, 1)
        var bi = ""
        if idx + 1 < sentence_hiragana.length():
            bi = sentence_hiragana.substr(idx, 2)
        var tri = ""
        if idx + 2 < sentence_hiragana.length():
            tri = sentence_hiragana.substr(idx, 3)

        if uni == "ー":
            valid_type_list = ["-"]
            idx += 1
            parsed_str.append(uni)
        elif uni == "・":
            valid_type_list = ["/", ".", "・"]
            idx += 1
            parsed_str.append(uni)
        elif _mapping_dictionary.has(tri):
            valid_type_list = _mapping_dictionary[tri]
            idx += 3
            parsed_str.append(tri)
        elif _mapping_dictionary.has(bi):
            valid_type_list = _mapping_dictionary[bi]
            idx += 2
            parsed_str.append(bi)
        elif _mapping_dictionary.has(uni):
            valid_type_list = _mapping_dictionary[uni]
            idx += 1
            parsed_str.append(uni)
        else:
            valid_type_list = [uni]
            idx += 1
            parsed_str.append(uni)

        judge.append(valid_type_list)

    return [parsed_str, judge]
