extends Node2D

const CARD_SCENE := preload("res://scenes/kanji_dex/KanjiCard.tscn")

@onready var grid        : GridContainer = $UI/Root/VBox/ScrollContainer/Grid
@onready var stats_label : Label         = $UI/Root/VBox/StatsLabel
@onready var back_button : Button        = get_node_or_null("UI/Root/VBox/TitleBar/BackButton")
@onready var zone_filter : OptionButton  = get_node_or_null("UI/Root/VBox/TitleBar/ZoneFilter")

var _current_filter : int = -1   # -1 = toutes les zones

func _ready() -> void:
	NavBar.show_for_scene("dex")
	# Le bouton retour devient redondant avec NavBar — mais on le laisse fonctionnel s'il existe
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
		back_button.text = "← Battle"   # Returns to battle
	_setup_zone_filter()
	_populate_grid()

func _setup_zone_filter() -> void:
	if zone_filter == null:
		# Si la scène n'a pas de filtre de zone, on en crée un
		var titlebar := get_node_or_null("UI/Root/VBox/TitleBar")
		if titlebar == null: return
		zone_filter = OptionButton.new()
		zone_filter.name = "ZoneFilter"
		zone_filter.custom_minimum_size = Vector2(160, 40)
		titlebar.add_child(zone_filter)
	else:
		zone_filter.clear()
	zone_filter.add_item("All zones", -1)
	for z in ZoneManager.get_all():
		zone_filter.add_item(z["name"], z["id"])
	zone_filter.item_selected.connect(_on_filter_changed)

func _on_filter_changed(idx: int) -> void:
	_current_filter = zone_filter.get_item_id(idx)
	_populate_grid()

func _populate_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	var kanjis : Array = KanjiDB.get_all() if _current_filter == -1 \
				else KanjiDB.get_by_zone(_current_filter)
	var discovered := GameManager.data.discovered_kanji_ids
	var found_count := 0
	var total_count := kanjis.size()

	for kanji in kanjis:
		var is_discovered = kanji["id"] in discovered
		if is_discovered:
			found_count += 1
		var card := CARD_SCENE.instantiate() as PanelContainer
		grid.add_child(card)
		card.call_deferred("setup", kanji, is_discovered)

	stats_label.text = "%d / %d kanjis discovered" % [found_count, total_count]

func _on_back_pressed() -> void:
	GameManager.go_to("res://scenes/game_world/GameWorld.tscn")
