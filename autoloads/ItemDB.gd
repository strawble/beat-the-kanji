extends Node

var _items : Array = []

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
	print("ItemDB: %d items loaded." % _items.size())

func get_all() -> Array:
	return _items

func get_by_id(id: int) -> Dictionary:
	for item in _items:
		if item["id"] == id:
			return item
	return {}

func get_by_type(type: String) -> Array:
	return _items.filter(func(i): return i["type"] == type)
