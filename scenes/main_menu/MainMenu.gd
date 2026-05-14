extends Node2D

@onready var play_button    : Button = $UI/Root/VBox/PlayButton
@onready var map_button     : Button = $UI/Root/VBox/MapButton
@onready var dex_button     : Button = $UI/Root/VBox/DexButton
@onready var help_button    : Button = $UI/Root/VBox/HelpButton
@onready var credits_button : Button = $UI/Root/VBox/CreditsButton
@onready var stats_label    : Label  = $UI/Root/VBox/StatsLabel

func _ready() -> void:
	NavBar.hide_navbar()

	play_button.pressed.connect(_on_play)
	map_button.pressed.connect(_on_map)
	dex_button.pressed.connect(_on_dex)
	help_button.pressed.connect(_on_help)
	credits_button.pressed.connect(_on_credits)
	_refresh_stats()

func _refresh_stats() -> void:
	var d     = GameManager.data
	var total = KanjiDB.get_all().size()
	var found = d.discovered_kanji_ids.size()
	var zone  = ZoneManager.get_active_zone()
	var zone_name : String = zone.get("name", "—") if not zone.is_empty() else "—"
	stats_label.text = "Level %d   ·   %d / %d kanjis   ·   %d 🪙   ·   Zone: %s" \
					% [d.player_level, found, total, d.coins, zone_name]

func _on_play() -> void:
	GameManager.go_to("res://scenes/game_world/GameWorld.tscn")

func _on_map() -> void:
	GameManager.go_to("res://scenes/world_map/WorldMap.tscn")

func _on_dex() -> void:
	GameManager.go_to("res://scenes/kanji_dex/KanjiDex.tscn")

func _on_help() -> void:
	GameManager.go_to("res://scenes/help/Help.tscn")

func _on_credits() -> void:
	GameManager.go_to("res://scenes/credits/Credits.tscn")
