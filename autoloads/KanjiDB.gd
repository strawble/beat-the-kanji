extends Node

var _kanjis : Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file = FileAccess.open("res://data/kanji_data.json", FileAccess.READ)
	if not file:
		push_error("KanjiDB: cannot open kanji_data.json")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("KanjiDB: invalid JSON — " + json.get_error_message())
		return
	_kanjis = json.data["kanjis"]
	print("KanjiDB: %d kanjis loaded." % _kanjis.size())

# ── Queries ────────────────────────────────────────────────────────────────────

func get_all() -> Array:
	return _kanjis

func get_by_id(id: int) -> Dictionary:
	for k in _kanjis:
		if k["id"] == id:
			return k
	return {}

func get_unlocked(player_level: int) -> Array:
	return _kanjis.filter(func(k): return k["unlock_at_player_level"] <= player_level)

func get_unlocked_in_zone(player_level: int, zone_id: int) -> Array:
	return _kanjis.filter(func(k):
		return k["unlock_at_player_level"] <= player_level \
		   and k.get("zone_id", 1) == zone_id
	)

func get_by_zone(zone_id: int) -> Array:
	return _kanjis.filter(func(k): return k.get("zone_id", 1) == zone_id)

# ── MCQ Question ───────────────────────────────────────────────────────────────

func build_question(kanji: Dictionary) -> Dictionary:
	var unlocked = get_unlocked(GameManager.data.player_level)
	var types = ["meaning", "character", "kun_yomi", "on_yomi"]
	if kanji["kun_yomi"].is_empty(): types.erase("kun_yomi")
	if kanji["on_yomi"].is_empty():  types.erase("on_yomi")
	var type = types[randi() % types.size()]

	var prompt  : String = ""
	var correct : String = ""

	match type:
		"meaning":
			prompt  = "What does  " + kanji["character"] + "  mean?"
			correct = kanji["meanings"][0]
		"character":
			prompt  = "Which kanji means  \"" + kanji["meanings"][0] + "\"?"
			correct = kanji["character"]
		"kun_yomi":
			prompt  = "Kun'yomi of  " + kanji["character"] + "  ?"
			correct = kanji["kun_yomi"][0]
		"on_yomi":
			prompt  = "On'yomi of  " + kanji["character"] + "  ?"
			correct = kanji["on_yomi"][0]

	return {
		"kanji_id": kanji["id"],
		"type":     type,
		"prompt":   prompt,
		"correct":  correct,
		"choices":  _build_choices(correct, type, kanji["id"], unlocked)
	}

func _build_choices(correct: String, type: String,
					exclude_id: int, pool: Array) -> Array:
	var choices: Array = [correct]
	var others = pool.filter(func(k): return k["id"] != exclude_id)
	others.shuffle()
	for k in others:
		if choices.size() >= 4:
			break
		var val := _extract_field(k, type)
		if val != "" and val not in choices:
			choices.append(val)
	while choices.size() < 4:
		choices.append("—")
	choices.shuffle()
	return choices

func _extract_field(kanji: Dictionary, type: String) -> String:
	match type:
		"meaning":   return kanji["meanings"][0]  if not kanji["meanings"].is_empty() else ""
		"character": return kanji["character"]
		"kun_yomi":  return kanji["kun_yomi"][0]  if not kanji["kun_yomi"].is_empty() else ""
		"on_yomi":   return kanji["on_yomi"][0]   if not kanji["on_yomi"].is_empty()  else ""
	return ""

# ── Progressive hints ──────────────────────────────────────────────────────────
# Returns a progressive hint text (level 1 = subtle, level 3 = very revealing)
func build_hint(kanji: Dictionary, question_type: String, hint_level: int) -> String:
	match question_type:
		"meaning":
			match hint_level:
				1: return "Hint: this kanji has %d stroke(s)." % kanji.get("stroke_count", 0)
				2:
					var first_meaning : String = kanji["meanings"][0]
					return "Hint: the meaning starts with '%s'." % first_meaning.substr(0, 1)
				_:
					var first_meaning : String = kanji["meanings"][0]
					return "Hint: the meaning is %d letters long and starts with '%s'." % [first_meaning.length(), first_meaning.substr(0, 1)]
		"character":
			match hint_level:
				1: return "Hint: this kanji has %d stroke(s)." % kanji.get("stroke_count", 0)
				2:
					if not kanji["on_yomi"].is_empty():
						return "Hint: on'yomi = %s" % kanji["on_yomi"][0]
					return "Hint: kun'yomi = %s" % kanji["kun_yomi"][0]
				_: return "Hint: the answer is  %s" % kanji["character"]
		"kun_yomi":
			match hint_level:
				1: return "Hint: %d character(s)." % kanji["kun_yomi"][0].length()
				2: return "Hint: starts with '%s'." % kanji["kun_yomi"][0].substr(0, 1)
				_: return "Hint: %s" % kanji["kun_yomi"][0]
		"on_yomi":
			match hint_level:
				1: return "Hint: %d character(s)." % kanji["on_yomi"][0].length()
				2: return "Hint: starts with '%s'." % kanji["on_yomi"][0].substr(0, 1)
				_: return "Hint: %s" % kanji["on_yomi"][0]
	return ""
