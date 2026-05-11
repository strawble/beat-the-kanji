extends Control

# Signal : success=bool (seuil atteint ou non), coverage=float (0.0–1.0)
signal drawing_validated(success: bool, coverage: float)

const CANVAS_SIZE        : Vector2 = Vector2(300, 300)
const STROKE_WIDTH       : float   = 8.0
const COVERAGE_THRESHOLD : float   = 0.40   # seuil pour "réussi"

var current_kanji   : Dictionary = {}
var current_attempt : int = 1
var max_attempts    : int = 3

var _is_drawing     : bool = false
var _current_stroke : Array[Vector2] = []
var _all_strokes    : Array = []

var canvas_node   : Control = null
var attempt_label : Label   = null
var hint_label    : Label   = null
var guide_label   : Label   = null
var coverage_bar  : ProgressBar = null   # feedback visuel du score

func setup(kanji: Dictionary, attempt_start: int = 1) -> void:
	current_kanji   = kanji
	current_attempt = clamp(attempt_start, 1, max_attempts)
	_reset_drawing()
	_update_ui()

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Fond opaque pour masquer le jeu derrière
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	attempt_label = Label.new()
	attempt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attempt_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(attempt_label)

	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint_label)

	# Zone de dessin
	var canvas_container := PanelContainer.new()
	canvas_container.custom_minimum_size    = CANVAS_SIZE
	canvas_container.size_flags_horizontal  = Control.SIZE_SHRINK_CENTER
	vbox.add_child(canvas_container)

	# Guide en filigrane (placeholder — remplacer par TextureRect + images)
	guide_label = Label.new()
	guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guide_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	guide_label.add_theme_font_size_override("font_size", 160)
	guide_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_container.add_child(guide_label)

	canvas_node = Control.new()
	canvas_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_node.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_node.draw.connect(_on_canvas_draw)
	canvas_node.gui_input.connect(_on_canvas_input)
	canvas_container.add_child(canvas_node)

	# Barre de couverture (feedback)
	coverage_bar = ProgressBar.new()
	coverage_bar.custom_minimum_size = Vector2(0, 10)
	coverage_bar.max_value           = 1.0
	coverage_bar.value               = 0.0
	coverage_bar.show_percentage     = false
	coverage_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	coverage_bar.custom_minimum_size   = CANVAS_SIZE
	vbox.add_child(coverage_bar)

	# Boutons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_hbox)

	var clear_btn := Button.new()
	clear_btn.text = "🗑  Effacer"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.pressed.connect(_on_clear_pressed)
	btn_hbox.add_child(clear_btn)

	var validate_btn := Button.new()
	validate_btn.text = "✅  Valider"
	validate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	validate_btn.pressed.connect(_on_validate_pressed)
	btn_hbox.add_child(validate_btn)

	var give_up_btn := Button.new()
	give_up_btn.text = "⏩  Passer"
	give_up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	give_up_btn.pressed.connect(_on_give_up_pressed)
	btn_hbox.add_child(give_up_btn)

func _update_ui() -> void:
	if current_kanji.is_empty(): return
	var char_str : String = current_kanji.get("character", "?")
	attempt_label.text = "Essai %d / %d — Tracez  %s" % [current_attempt, max_attempts, char_str]

	# Placeholder : "{numéro}{kanji}" ex: "1日", "2日", "3日"
	# → remplacez guide_label par TextureRect + vos images PNG
	guide_label.text = "%d%s" % [current_attempt, char_str]

	match current_attempt:
		1:
			guide_label.modulate = Color(0.4, 0.6, 1.0, 0.85)
			hint_label.text = "✏️  Tous les traits sont montrés — recouvrez le modèle"
		2:
			guide_label.modulate = Color(0.4, 0.6, 1.0, 0.45)
			var stroke_count  : int = current_kanji.get("stroke_count", 4)
			var shown_strokes : int = max(1, stroke_count / 2)
			hint_label.text = "✏️  %d traits montrés — complétez le reste" % shown_strokes
		3:
			guide_label.modulate = Color(0.4, 0.6, 1.0, 0.20)
			var first_hint : String = current_kanji.get("first_stroke_hint", "")
			hint_label.text = ("✏️  Premier trait : " + first_hint) if first_hint != "" \
							  else "✏️  Tracez de mémoire !"

# ── Dessin ─────────────────────────────────────────────────────────────────────
func _on_canvas_input(event: InputEvent) -> void:
	var pos      : Vector2 = Vector2.ZERO
	var pressed  : bool    = false
	var released : bool    = false

	if event is InputEventMouseButton:
		var mbe : InputEventMouseButton = event as InputEventMouseButton
		pos      = mbe.position
		pressed  = mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT
		released = not mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventMouseMotion:
		if _is_drawing:
			_current_stroke.append((event as InputEventMouseMotion).position)
			canvas_node.queue_redraw()
			_update_coverage_bar()
		return
	elif event is InputEventScreenTouch:
		var ste : InputEventScreenTouch = event as InputEventScreenTouch
		pos = ste.position ; pressed = ste.pressed ; released = not ste.pressed
	elif event is InputEventScreenDrag:
		_current_stroke.append((event as InputEventScreenDrag).position)
		canvas_node.queue_redraw()
		_update_coverage_bar()
		return

	if pressed:
		_is_drawing = true
		_current_stroke = [pos]
	elif released and _is_drawing:
		_is_drawing = false
		if _current_stroke.size() > 2:
			_all_strokes.append(_current_stroke.duplicate())
		_current_stroke.clear()
		canvas_node.queue_redraw()
		_update_coverage_bar()

func _on_canvas_draw() -> void:
	for stroke in _all_strokes:
		if (stroke as Array).size() < 2: continue
		for i in range((stroke as Array).size() - 1):
			canvas_node.draw_line(stroke[i], stroke[i + 1], Color(0.1, 0.1, 0.1, 0.9), STROKE_WIDTH, true)
	if _current_stroke.size() >= 2:
		for i in range(_current_stroke.size() - 1):
			canvas_node.draw_line(_current_stroke[i], _current_stroke[i + 1], Color(0.1, 0.4, 0.9, 0.9), STROKE_WIDTH, true)

func _update_coverage_bar() -> void:
	if coverage_bar:
		coverage_bar.value = _compute_coverage()
		var c : float = coverage_bar.value
		coverage_bar.modulate = Color(1.0 - c, c * 0.8 + 0.2, 0.2, 1.0)

# ── Validation ─────────────────────────────────────────────────────────────────
func _on_validate_pressed() -> void:
	if _all_strokes.is_empty():
		hint_label.text = "⚠️  Dessinez quelque chose d'abord !"
		return

	var coverage : float = _compute_coverage()
	var success  : bool  = coverage >= COVERAGE_THRESHOLD
	emit_signal("drawing_validated", success, coverage)

	if success:
		hint_label.text = "✨  Tracé validé ! (couverture : %d%%)" % int(coverage * 100)
	else:
		if current_attempt < max_attempts:
			current_attempt += 1
			hint_label.text = "❌  Insuffisant (%d%%) — essai suivant !" % int(coverage * 100)
			await get_tree().create_timer(1.2).timeout
			_reset_drawing()
			_update_ui()
		else:
			hint_label.text = "❌  Tentatives épuisées (%d%%)" % int(coverage * 100)
			await get_tree().create_timer(1.0).timeout
			emit_signal("drawing_validated", false, coverage)

func _on_clear_pressed() -> void:
	_reset_drawing()
	_update_coverage_bar()

func _on_give_up_pressed() -> void:
	emit_signal("drawing_validated", false, 0.0)

# ── Score de couverture (grille 4×4 = 16 cellules) ────────────────────────────
func _compute_coverage() -> float:
	var grid : Dictionary = {}
	var all : Array = _all_strokes.duplicate()
	if not _current_stroke.is_empty():
		all.append(_current_stroke)
	for stroke in all:
		for pt in (stroke as Array):
			var cell := Vector2i(
				int(pt.x / (CANVAS_SIZE.x / 4.0)),
				int(pt.y / (CANVAS_SIZE.y / 4.0))
			)
			cell.x = clamp(cell.x, 0, 3)
			cell.y = clamp(cell.y, 0, 3)
			grid[cell] = true
	return float(grid.size()) / 16.0

func _reset_drawing() -> void:
	_all_strokes.clear()
	_current_stroke.clear()
	_is_drawing = false
	if canvas_node: canvas_node.queue_redraw()
	if coverage_bar: coverage_bar.value = 0.0
