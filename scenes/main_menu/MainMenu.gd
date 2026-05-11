extends Node2D

# Définition des niveaux disponibles
# Chaque niveau spécifie les IDs de kanjis à apprendre
const LEVELS : Array = [
	{
		"id":          1,
		"title":       "Niveau 1",
		"subtitle":    "Soleil · Lune · Feu",
		"kanji_ids":   [1, 2, 3],   # 日 月 火
		"unlocked":    true,
	},
]

@onready var dex_button   : Button = $UI/Root/VBox/DexButton
@onready var stats_label  : Label  = $UI/Root/VBox/StatsLabel
@onready var levels_vbox  : VBoxContainer = $UI/Root/VBox/LevelsVBox

func _ready() -> void:
	dex_button.pressed.connect(_on_dex)
	_refresh_stats()
	_build_level_list()

func _refresh_stats() -> void:
	var d : PlayerData   = GameManager.data
	var total : int = KanjiDB.get_all().size()
	var found : int = d.discovered_kanji_ids.size()
	stats_label.text = "Niveau %d   —   %d / %d kanjis   —   %d 🪙" \
					   % [d.player_level, found, total, d.coins]

func _build_level_list() -> void:
	for child in levels_vbox.get_children():
		child.queue_free()

	for level in LEVELS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 70)
		btn.text = "%s\n%s" % [level["title"], level["subtitle"]]
		btn.disabled = not level["unlocked"]
		var lid : int = level["id"]
		btn.pressed.connect(func(): _start_level(lid))
		levels_vbox.add_child(btn)

func _start_level(level_id: int) -> void:
	# Cherche les données du niveau
	for level in LEVELS:
		if level["id"] == level_id:
			# Stocke les kanji_ids du niveau dans GameManager pour GameWorld
			GameManager.set_current_level(level)
			GameManager.go_to("res://scenes/game_world/GameWorld.tscn")
			return

func _on_dex() -> void:
	GameManager.go_to("res://scenes/kanji_dex/KanjiDex.tscn")
