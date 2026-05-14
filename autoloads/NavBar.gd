extends CanvasLayer
# Barre de navigation globale visible en bas de l'écran sur toutes les scènes
# de jeu (GameWorld, Shop, KanjiDex, WorldMap). Cachée sur MainMenu.

const SCENES := {
	"combat": "res://scenes/game_world/GameWorld.tscn",
	"map":    "res://scenes/world_map/WorldMap.tscn",
	"shop":   "res://scenes/shop/Shop.tscn",
	"dex":    "res://scenes/kanji_dex/KanjiDex.tscn",
}

const TAB_LABELS := {
	"combat": "⚔ Battle",
	"map":    "🗺 Map",
	"shop":   "🛒 Shop",
	"dex":    "📖 KanjiDex",
}

const TAB_ORDER : Array = ["combat", "map", "shop", "dex"]

var _bar         : PanelContainer
var _tab_buttons : Dictionary = {}
var _current_tab : String = ""

func _ready() -> void:
	layer = 100   # Au-dessus de tout
	_build_ui()
	hide_navbar()   # cachée par défaut, chaque scène l'active

func _build_ui() -> void:
	_bar = PanelContainer.new()
	_bar.anchor_left   = 0.0
	_bar.anchor_right  = 1.0
	_bar.anchor_top    = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top    = -64
	_bar.offset_bottom = 0
	_bar.offset_left   = 0
	_bar.offset_right  = 0
	add_child(_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	_bar.add_child(hbox)

	for key in TAB_ORDER:
		var btn := Button.new()
		btn.text = TAB_LABELS[key]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 14)
		# Évite le souci de capture dans les lambdas de boucle
		var k = key
		btn.pressed.connect(func(): _on_tab_pressed(k))
		hbox.add_child(btn)
		_tab_buttons[key] = btn

func _on_tab_pressed(key: String) -> void:
	if key == _current_tab:
		return
	if SCENES.has(key):
		GameManager.go_to(SCENES[key])

# ── API publique ───────────────────────────────────────────────────────────────

func show_for_scene(active_tab: String) -> void:
	_current_tab = active_tab
	for key in _tab_buttons:
		var btn : Button = _tab_buttons[key]
		if key == active_tab:
			btn.modulate = Color(1.0, 0.85, 0.4)   # surligne l'onglet actif
			btn.disabled = true
		else:
			btn.modulate = Color.WHITE
			btn.disabled = false
	visible = true

func hide_navbar() -> void:
	visible = false
	_current_tab = ""

# Hauteur réservée pour les scènes (à ajouter en margin_bottom des MarginContainer racine)
func get_height() -> int:
	return 64
