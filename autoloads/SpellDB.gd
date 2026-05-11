extends Node

# Base de données des sorts créés par combinaison de kanjis
# Un sort = une liste ordonnée de kanji IDs + un effet

var _spells: Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file = FileAccess.open("res://data/spell_data.json", FileAccess.READ)
	if not file:
		push_error("SpellDB: impossible d'ouvrir spell_data.json")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("SpellDB: JSON invalide — " + json.get_error_message())
		return
	_spells = json.data["spells"]
	print("SpellDB: %d sorts chargés." % _spells.size())

# Retourne le sort correspondant à une combinaison de kanji IDs (ordre important)
func find_spell(kanji_ids: Array) -> Dictionary:
	for spell in _spells:
		if spell["kanji_ids"] == kanji_ids:
			return spell
	return {}

# Retourne tous les sorts réalisables avec les kanjis découverts par le joueur
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

# Retourne tous les sorts (pour l'UI de sélection)
func get_all() -> Array:
	return _spells
