extends CanvasLayer
class_name ParryOverlay

# Overlay qui s'affiche quand le boss prépare une attaque.
# Le joueur a un temps limité pour tracer le bon kanji.
# Émet `parry_resolved(success: bool, score: float)` à la fin.

signal parry_resolved(success: bool, score: float)

const PARRY_TIME    : float = 5.0
const SCORE_THRESHOLD : float = 0.5

# Références aux nœuds (créés dynamiquement dans _ready si pas en scène)
var _bg          : ColorRect
var _panel       : PanelContainer
var _title_label : Label
var _meaning_label : Label
var _drawing     : KanjiDrawing
var _info_label  : Label
var _timer_bar   : ProgressBar
var _validate_btn: Button
var _retry_btn   : Button

var _kanji        : Dictionary = {}
var _remaining    : float = 0.0
var _running      : bool  = false

func _ready() -> void:
	layer = 50   # Sous la NavBar (100) mais au-dessus du gameplay
	_build_ui()
	visible = false

func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0.75)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	var center := CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	_title_label = Label.new()
	_title_label.text = "⚠ Le boss attaque !"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))
	v.add_child(_title_label)

	var sub := Label.new()
	sub.text = "Tracez le kanji pour parer :"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	v.add_child(sub)

	_meaning_label = Label.new()
	_meaning_label.text = "—"
	_meaning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meaning_label.add_theme_font_size_override("font_size", 26)
	_meaning_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	v.add_child(_meaning_label)

	_drawing = KanjiDrawing.new()
	_drawing.custom_minimum_size = Vector2(280, 280)
	_drawing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_drawing)

	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(0, 14)
	v.add_child(_timer_bar)

	_info_label = Label.new()
	_info_label.text = ""
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.custom_minimum_size = Vector2(0, 24)
	v.add_child(_info_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	v.add_child(btns)

	_retry_btn = Button.new()
	_retry_btn.text = "Effacer"
	_retry_btn.custom_minimum_size = Vector2(0, 44)
	_retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_retry_btn.pressed.connect(_on_retry)
	btns.add_child(_retry_btn)

	_validate_btn = Button.new()
	_validate_btn.text = "Valider"
	_validate_btn.custom_minimum_size = Vector2(0, 44)
	_validate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_validate_btn.pressed.connect(_on_validate)
	btns.add_child(_validate_btn)

func _process(delta: float) -> void:
	if not _running:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = 0.0
		_resolve(false, 0.0, "Trop tard !")
		return
	_timer_bar.value = _remaining

# ── API ────────────────────────────────────────────────────────────────────────

func start_parry(kanji: Dictionary) -> void:
	_kanji = kanji
	_drawing.clear()
	_drawing.set_enabled(true)
	_meaning_label.text = "%s" % ", ".join(kanji["meanings"])
	_info_label.text = ""
	_remaining = PARRY_TIME
	_timer_bar.max_value = PARRY_TIME
	_timer_bar.value = PARRY_TIME
	_validate_btn.disabled = false
	_retry_btn.disabled = false
	_running = true
	visible = true

func _on_validate() -> void:
	if not _running:
		return
	var expected : int   = _kanji.get("stroke_count", 0)
	var score    : float = _drawing.compute_score(expected)
	var success  : bool  = score >= SCORE_THRESHOLD
	var msg : String
	if success:
		msg = "✓ Parry réussi ! Contre-attaque ! (score : %d%%)" % int(score * 100)
	else:
		msg = "✗ Parry raté (score : %d%% / %d%% requis)" % [int(score * 100), int(SCORE_THRESHOLD * 100)]
	_resolve(success, score, msg)

func _on_retry() -> void:
	_drawing.clear()
	_info_label.text = ""

func _resolve(success: bool, score: float, msg: String) -> void:
	_running = false
	_drawing.set_enabled(false)
	_validate_btn.disabled = true
	_retry_btn.disabled = true
	_info_label.text = msg
	_info_label.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.5) if success else Color(1.0, 0.4, 0.4))
	# Petit délai avant de fermer l'overlay
	await get_tree().create_timer(1.5).timeout
	visible = false
	emit_signal("parry_resolved", success, score)
