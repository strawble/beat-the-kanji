extends Node

var _zones : Array = []

signal zone_changed(new_zone_id: int)
signal zone_unlocked(zone_id: int)

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file = FileAccess.open("res://data/zones_data.json", FileAccess.READ)
	if not file:
		push_error("ZoneManager: cannot open zones_data.json")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("ZoneManager: invalid JSON — " + json.get_error_message())
		return
	_zones = json.data["zones"]
	print("ZoneManager: %d zones loaded." % _zones.size())

# ── Lecture ────────────────────────────────────────────────────────────────────

func get_all() -> Array:
	return _zones

func get_zone_by_id(id: int) -> Dictionary:
	for z in _zones:
		if z["id"] == id:
			return z
	return {}

func get_active_zone() -> Dictionary:
	return get_zone_by_id(GameManager.data.active_zone_id)

func is_unlocked(zone_id: int) -> bool:
	return zone_id in GameManager.data.unlocked_zone_ids

func is_available(zone_id: int) -> bool:
	var zone := get_zone_by_id(zone_id)
	if zone.is_empty():
		return false
	return GameManager.data.player_level >= zone["unlock_at_player_level"]

# ── Actions ────────────────────────────────────────────────────────────────────

func unlock_zone(zone_id: int) -> bool:
	var zone := get_zone_by_id(zone_id)
	if zone.is_empty():
		return false
	if is_unlocked(zone_id):
		return true
	if not is_available(zone_id):
		push_warning("ZoneManager: level too low for zone %d" % zone_id)
		return false
	if not GameManager.spend_coins(zone["cost_coins"]):
		push_warning("ZoneManager: not enough coins for zone %d" % zone_id)
		return false
	GameManager.data.unlocked_zone_ids.append(zone_id)
	GameManager.save_game()
	emit_signal("zone_unlocked", zone_id)
	print("ZoneManager: zone %d unlocked." % zone_id)
	return true

func set_active_zone(zone_id: int) -> bool:
	if not is_unlocked(zone_id):
		push_warning("ZoneManager: zone %d not unlocked" % zone_id)
		return false
	GameManager.data.active_zone_id = zone_id
	GameManager.save_game()
	emit_signal("zone_changed", zone_id)
	print("ZoneManager: active zone → %d" % zone_id)
	return true
