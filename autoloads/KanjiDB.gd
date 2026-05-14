extends Node

var _kanjis: Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file = FileAccess.open("res://data/kanji_data.json", FileAccess.READ)
	if not file:
		push_error("KanjiDB: cannot open kanji_data.json")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("KanjiDB: invalid JSON")
		return
	_kanjis = json.data["kanjis"]
	print("KanjiDB: %d kanjis loaded." % _kanjis.size())

func get_unlocked(player_level: int) -> Array:
	return _kanjis.filter(func(k): return k["unlock_at_player_level"] <= player_level)

func get_all() -> Array:
	return _kanjis

func get_by_id(id: int) -> Dictionary:
	for k in _kanjis:
		if int(k["id"]) == id:
			return k
	return {}

# pool_override: if provided, distractors come ONLY from this pool
func build_question(kanji: Dictionary, pool_override: Array = []) -> Dictionary:
	var pool : Array = pool_override if not pool_override.is_empty() \
					   else get_unlocked(GameManager.data.player_level)
	# Pick a valid question type for this kanji
	var types : Array = ["meaning", "character", "kun_yomi", "on_yomi"]
	if (kanji["kun_yomi"] as Array).is_empty(): types.erase("kun_yomi")
	if (kanji["on_yomi"]  as Array).is_empty(): types.erase("on_yomi")
	var type : String = types[randi() % types.size()]
	var prompt  : String = ""
	var correct : String = ""
	match type:
		"meaning":
			prompt  = "What does  " + kanji["character"] + "  mean?"
			correct = (kanji["meanings"] as Array)[0]
		"character":
			prompt  = "Which kanji means  \"" + (kanji["meanings"] as Array)[0] + "\"  ?"
			correct = kanji["character"]
		"kun_yomi":
			prompt  = "Kun'yomi of  " + kanji["character"] + "  ?"
			correct = (kanji["kun_yomi"] as Array)[0]
		"on_yomi":
			prompt  = "On'yomi of  " + kanji["character"] + "  ?"
			correct = (kanji["on_yomi"] as Array)[0]
	return {
		"kanji_id": int(kanji["id"]),
		"type":     type,
		"prompt":   prompt,
		"correct":  correct,
		"choices":  _build_choices(correct, type, int(kanji["id"]), pool)
	}

func _build_choices(correct: String, type: String,
					exclude_id: int, pool: Array) -> Array:
	var choices : Array = [correct]
	# Collect ALL possible values from the pool (excluding the current kanji)
	var candidates : Array = []
	for k in pool:
		if int(k["id"]) == exclude_id:
			continue
		# Add all values of this type for this kanji
		match type:
			"meaning":
				for m in (k["meanings"] as Array):
					if m != "" and m not in candidates: candidates.append(m)
			"character":
				var c : String = k["character"]
				if c not in candidates: candidates.append(c)
			"kun_yomi":
				for r in (k["kun_yomi"] as Array):
					if r != "" and r not in candidates: candidates.append(r)
			"on_yomi":
				for r in (k["on_yomi"] as Array):
					if r != "" and r not in candidates: candidates.append(r)
	candidates.shuffle()
	for c in candidates:
		if c not in choices:
			choices.append(c)
		if choices.size() >= 4:
			break
	# If still not enough (very small pool), draw from other types of the same kanji
	if choices.size() < 4:
		for k in pool:
			if int(k["id"]) == exclude_id:
				continue
			for t in ["meaning", "character", "kun_yomi", "on_yomi"]:
				if t == type: continue
				var v : String = _extract_field(k, t)
				if v != "" and v not in choices:
					choices.append(v)
				if choices.size() >= 4:
					break
			if choices.size() >= 4:
				break
	choices.shuffle()
	return choices

func _extract_field(kanji: Dictionary, type: String) -> String:
	match type:
		"meaning":   return (kanji["meanings"] as Array)[0] if not (kanji["meanings"] as Array).is_empty() else ""
		"character": return kanji["character"]
		"kun_yomi":  return (kanji["kun_yomi"] as Array)[0] if not (kanji["kun_yomi"] as Array).is_empty() else ""
		"on_yomi":   return (kanji["on_yomi"]  as Array)[0] if not (kanji["on_yomi"]  as Array).is_empty() else ""
	return ""
