extends Node2D

const ZONE_CARD_SCENE := preload("res://scenes/world_map/ZoneCard.tscn")

@onready var grid           : GridContainer = $UI/Root/VBox/ScrollContainer/Grid
@onready var info_label     : Label         = $UI/Root/VBox/InfoLabel
@onready var current_label  : Label         = $UI/Root/VBox/CurrentZoneLabel

func _ready() -> void:
	NavBar.show_for_scene("map")
	_populate_grid()
	_refresh_current_zone()

func _populate_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	for zone in ZoneManager.get_all():
		var card := ZONE_CARD_SCENE.instantiate()
		grid.add_child(card)
		card.call_deferred("setup", zone)
		card.zone_action_requested.connect(_on_zone_action)

func _refresh_current_zone() -> void:
	var z := ZoneManager.get_active_zone()
	if z.is_empty():
		current_label.text = "Active zone: —"
	else:
		current_label.text = "Active zone: %s" % z["name"]

func _on_zone_action(zone_id: int, action: String) -> void:
	match action:
		"unlock":
			if ZoneManager.unlock_zone(zone_id):
				_show_info("✓ Zone unlocked !", true)
			else:
				_show_info("✗ Not enough coins or level too low", false)
		"activate":
			if ZoneManager.set_active_zone(zone_id):
				_show_info("✓ Active zone changed", true)
	_refresh_current_zone()
	# Rafraîchit toutes les cartes (le statut a pu changer)
	for c in grid.get_children():
		if c.has_method("refresh"):
			c.refresh()

func _show_info(msg: String, positive: bool) -> void:
	info_label.text = msg
	info_label.modulate = Color(0.4, 1.0, 0.5) if positive else Color(1.0, 0.4, 0.4)
	await get_tree().create_timer(2.0).timeout
	if info_label:
		info_label.text = ""
