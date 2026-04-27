extends Node2D

@onready var play_button  : Button = $UI/Root/VBox/PlayButton
@onready var dex_button   : Button = $UI/Root/VBox/DexButton
@onready var stats_label  : Label  = $UI/Root/VBox/StatsLabel

func _ready() -> void:
	play_button.pressed.connect(_on_play)
	dex_button.pressed.connect(_on_dex)
	_refresh_stats()

func _refresh_stats() -> void:
	var d     := GameManager.data
	var total := KanjiDB.get_all().size()
	var found := d.discovered_kanji_ids.size()
	stats_label.text = "Level %d   —   %d / %d kanjis discovered   —   %d 🪙" \
					   % [d.player_level, found, total, d.coins]

func _on_play() -> void:
	GameManager.go_to("res://scenes/game_world/GameWorld.tscn")

func _on_dex() -> void:
	GameManager.go_to("res://scenes/kanji_dex/KanjiDex.tscn")
