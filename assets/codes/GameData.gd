# GameData.gd
extends Node

var last_score: int = 0
var has_score: bool = false

# デバッグモード用
var debug_start_id: int = 0
var debug_end_id: int = 0
var is_debug_mode: bool = false

func set_score(score: int):
    last_score = score
    has_score = true

func get_score() -> int:
    return last_score

func has_valid_score() -> bool:
    return has_score

func clear_score():
    has_score = false
    last_score = 0

func set_debug_mode(start_id: int, end_id: int):
    debug_start_id = start_id
    debug_end_id = end_id
    is_debug_mode = true

func clear_debug_mode():
    is_debug_mode = false
    debug_start_id = 0
    debug_end_id = 0
