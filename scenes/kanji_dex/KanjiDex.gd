extends Node2D

const CARD_SCENE := preload("res://scenes/kanji_dex/KanjiCard.tscn")

@onready var grid        : GridContainer = $UI/Root/VBox/ScrollContainer/Grid
@onready var stats_label : Label         = $UI/Root/VBox/StatsLabel
@onready var back_button : Button        = $UI/Root/VBox/TitleBar/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_populate_grid()

func _populate_grid() -> void:
	# Vide la grille au cas où on y reviendrait plusieurs fois
	for child in grid.get_children():
		child.queue_free()

	var all_kanjis  := KanjiDB.get_all()
	var discovered  := GameManager.data.discovered_kanji_ids
	var found_count := 0

	for kanji in all_kanjis:
		var is_discovered = kanji["id"] in discovered
		if is_discovered:
			found_count += 1

		var card := CARD_SCENE.instantiate() as PanelContainer
		grid.add_child(card)
		# Appelle setup() après add_child pour que _ready() du card soit exécuté
		card.call_deferred("setup", kanji, is_discovered)

	stats_label.text = "%d / %d kanjis découverts" % [found_count, all_kanjis.size()]

func _on_back_pressed() -> void:
	GameManager.go_to("res://scenes/game_world/GameWorld.tscn")
