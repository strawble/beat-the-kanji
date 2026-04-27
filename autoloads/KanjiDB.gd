extends Node

var _kanjis: Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file = FileAccess.open("res://data/kanji_data.json", FileAccess.READ)
	if not file:
		push_error("KanjiDB: impossible d'ouvrir kanji_data.json")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("KanjiDB: JSON invalide — " + json.get_error_message())
		return
	_kanjis = json.data["kanjis"]
	print("KanjiDB: %d kanjis chargés." % _kanjis.size())

# Tous les kanjis débloqués pour un niveau joueur donné
func get_unlocked(player_level: int) -> Array:
	return _kanjis.filter(func(k): return k["unlock_at_player_level"] <= player_level)

func get_all() -> Array:
	return _kanjis

func get_by_id(id: int) -> Dictionary:
	for k in _kanjis:
		if k["id"] == id:
			return k
	return {}

# Génère une question MCQ à partir d'un kanji
func build_question(kanji: Dictionary) -> Dictionary:
	var unlocked = get_unlocked(GameManager.data.player_level)
	var types = ["meaning", "character", "kun_yomi", "on_yomi"]
	# Retire les types sans données
	if kanji["kun_yomi"].is_empty(): types.erase("kun_yomi")
	if kanji["on_yomi"].is_empty():  types.erase("on_yomi")
	var type = types[randi() % types.size()]

	var prompt  : String = ""
	var correct : String = ""

	match type:
		"meaning":
			prompt  = "Que signifie  " + kanji["character"] + "  ?"
			correct = kanji["meanings"][0]
		"character":
			prompt  = "Quel kanji signifie  \"" + kanji["meanings"][0] + "\"  ?"
			correct = kanji["character"]
		"kun_yomi":
			prompt  = "Kun'yomi de  " + kanji["character"] + "  ?"
			correct = kanji["kun_yomi"][0]
		"on_yomi":
			prompt  = "On'yomi de  " + kanji["character"] + "  ?"
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
	while choices.size() < 4:   # Complète si pool trop petit
		choices.append("—")
	choices.shuffle()
	return choices

func _extract_field(kanji: Dictionary, type: String) -> String:
	match type:
		"meaning":   return kanji["meanings"][0]   if not kanji["meanings"].is_empty()  else ""
		"character": return kanji["character"]
		"kun_yomi":  return kanji["kun_yomi"][0]   if not kanji["kun_yomi"].is_empty()  else ""
		"on_yomi":   return kanji["on_yomi"][0]    if not kanji["on_yomi"].is_empty()   else ""
	return ""
