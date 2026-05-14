extends Node

# Database of spells created by combining kanjis
# A spell = an ordered list of kanji IDs + an effect
var _spells: Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file = FileAccess.open("res://data/spell_data.json", FileAccess.READ)
	if not file:
		push_error("SpellDB: cannot open spell_data.json")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("SpellDB: invalid JSON — " + json.get_error_message())
		return
	_spells = json.data["spells"]
	print("SpellDB: %d spells loaded." % _spells.size())

# Returns the spell matching a combination of kanji IDs (order matters)
func find_spell(kanji_ids: Array) -> Dictionary:
	for spell in _spells:
		if spell["kanji_ids"] == kanji_ids:
			return spell
	return {}

# Returns all spells castable with the kanjis discovered by the player
func get_available_spells() -> Array:
	var discovered := GameManager.data.discovered_kanji_ids
	var available: Array = []
	for spell in _spells:
		var can_cast := true
		for kid in spell["kanji_ids"]:
			if kid not in discovered:
				can_cast = false
				break
		if can_cast:
			available.append(spell)
	return available

# Returns all spells (for the selection UI)
func get_all() -> Array:
	return _spells
