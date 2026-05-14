extends Node

var _items : Array = []
var _sets  : Array = []

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file = FileAccess.open("res://data/items_data.json", FileAccess.READ)
	if not file:
		push_error("ItemDB: cannot open items_data.json")
		return
	var json = JSON.new()
	json.parse(file.get_as_text())
	_items = json.data["items"]
	_sets  = json.data.get("sets", [])
	print("ItemDB: %d items, %d sets loaded." % [_items.size(), _sets.size()])

func get_all() -> Array:
	return _items

func get_sets() -> Array:
	return _sets

func get_set_by_tag(tag: String) -> Dictionary:
	for s in _sets:
		if s.get("tag", "") == tag:
			return s
	return {}

func get_by_id(id: int) -> Dictionary:
	for item in _items:
		if item["id"] == id:
			return item
	return {}

func get_by_type(type: String) -> Array:
	return _items.filter(func(i): return i["type"] == type)

func get_by_tier(tier: String) -> Array:
	return _items.filter(func(i): return i.get("tier", "common") == tier)

func get_effect_value(item: Dictionary, stat_name: String) -> float:
	for eff in item.get("effects", []):
		if eff.get("stat", "") == stat_name:
			return float(eff.get("value", 0))
	return 0.0

# Couleur associée à un tier (pour l'UI)
func tier_color(tier: String) -> Color:
	match tier:
		"common": return Color(0.85, 0.85, 0.85)
		"rare":   return Color(0.4, 0.7, 1.0)
		"epic":   return Color(0.85, 0.55, 1.0)
	return Color.WHITE
