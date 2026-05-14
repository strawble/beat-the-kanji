extends PanelContainer
class_name ZoneCard

# Card representing a zone in the WorldMap.
# 4 visual states: locked (level too low), purchasable, unlocked, active.

signal zone_action_requested(zone_id: int, action: String)
# action ∈ "unlock" (buy), "activate" (go to the zone)

@onready var bg            : ColorRect = $BG
@onready var name_label    : Label  = $VBox/NameLabel
@onready var status_label  : Label  = $VBox/StatusLabel
@onready var desc_label    : Label  = $VBox/DescLabel
@onready var info_label    : Label  = $VBox/InfoLabel
@onready var action_btn    : Button = $VBox/ActionBtn

var _zone : Dictionary = {}

func setup(zone: Dictionary) -> void:
	_zone = zone
	custom_minimum_size = Vector2(280, 220)

	name_label.text = zone["name"]
	desc_label.text = zone["description"]

	# Couleur de fond selon le thème
	var c := Color.from_string(zone.get("color_hex", "#444444"), Color(0.3, 0.3, 0.3))
	bg.color = Color(c.r, c.g, c.b, 0.4)

	for con in action_btn.pressed.get_connections():
		action_btn.pressed.disconnect(con.callable)

	_refresh_status()

func _refresh_status() -> void:
	var zid : int = _zone["id"]
	var unlocked := ZoneManager.is_unlocked(zid)
	var available := ZoneManager.is_available(zid)
	var is_active := GameManager.data.active_zone_id == zid

	if is_active:
		status_label.text = "★ ACTIVE ZONE"
		status_label.modulate = Color(1.0, 0.9, 0.3)
		action_btn.text = "✓ Selected"
		action_btn.disabled = true
	elif unlocked:
		status_label.text = "✓ Unlocked"
		status_label.modulate = Color(0.5, 1.0, 0.6)
		action_btn.text = "Travel here"
		action_btn.disabled = false
		action_btn.pressed.connect(func(): emit_signal("zone_action_requested", zid, "activate"))
	elif available:
		status_label.text = "🪙 Purchasable"
		status_label.modulate = Color(1.0, 0.8, 0.4)
		action_btn.text = "Buy (%d 🪙)" % _zone["cost_coins"]
		action_btn.disabled = GameManager.data.coins < _zone["cost_coins"]
		action_btn.pressed.connect(func(): emit_signal("zone_action_requested", zid, "unlock"))
	else:
		status_label.text = "🔒 Locked"
		status_label.modulate = Color(0.7, 0.7, 0.7)
		action_btn.text = "Level %d required" % _zone["unlock_at_player_level"]
		action_btn.disabled = true
		modulate = Color(0.7, 0.7, 0.7)
		return

	modulate = Color.WHITE
	# Kanji info
	var range_data : Array = _zone["kanji_level_range"]
	var total_kanjis := KanjiDB.get_by_zone(zid).size()
	info_label.text = "Levels %d-%d  ·  %d kanjis" % [range_data[0], range_data[1], total_kanjis]

func refresh() -> void:
	_refresh_status()
