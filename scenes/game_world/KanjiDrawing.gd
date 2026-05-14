extends Control
class_name KanjiDrawing

# Zone de dessin pour le système de parry.
# Capture les traits, calcule un score de similarité avec le kanji cible.

signal stroke_added(stroke_count: int)

const STROKE_WIDTH    : float = 4.0
const STROKE_COLOR    : Color = Color(0.95, 0.95, 0.95)
const BG_COLOR        : Color = Color(0.12, 0.12, 0.16)
const GUIDE_COLOR     : Color = Color(0.25, 0.25, 0.30, 0.6)

var _strokes      : Array = []      # Array of Array of Vector2
var _current      : PackedVector2Array = PackedVector2Array()
var _is_drawing   : bool = false
var _enabled      : bool = true

func _ready() -> void:
	custom_minimum_size = Vector2(280, 280)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_drawing = true
				_current = PackedVector2Array()
				_current.append(event.position)
			else:
				if _is_drawing and _current.size() > 1:
					_strokes.append(_current.duplicate())
					emit_signal("stroke_added", _strokes.size())
				_is_drawing = false
				_current = PackedVector2Array()
				queue_redraw()
	elif event is InputEventMouseMotion and _is_drawing:
		# Évite d'ajouter des points trop proches
		if _current.size() == 0 or _current[_current.size() - 1].distance_to(event.position) > 2.0:
			_current.append(event.position)
			queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_is_drawing = true
			_current = PackedVector2Array([event.position])
		else:
			if _is_drawing and _current.size() > 1:
				_strokes.append(_current.duplicate())
				emit_signal("stroke_added", _strokes.size())
			_is_drawing = false
			_current = PackedVector2Array()
			queue_redraw()
	elif event is InputEventScreenDrag and _is_drawing:
		_current.append(event.position)
		queue_redraw()

func _draw() -> void:
	# Fond
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)
	# Guides (croix centrale)
	var center : Vector2 = size / 2.0
	draw_line(Vector2(0, center.y), Vector2(size.x, center.y), GUIDE_COLOR, 1.0)
	draw_line(Vector2(center.x, 0), Vector2(center.x, size.y), GUIDE_COLOR, 1.0)
	# Bordure
	draw_rect(Rect2(Vector2.ZERO, size), GUIDE_COLOR, false, 1.0)
	# Traits enregistrés
	for s in _strokes:
		_draw_stroke(s)
	# Trait en cours
	if _current.size() > 1:
		_draw_stroke(_current)

func _draw_stroke(points) -> void:
	if points.size() < 2:
		return
	var packed := PackedVector2Array()
	for p in points:
		packed.append(p)
	draw_polyline(packed, STROKE_COLOR, STROKE_WIDTH, true)

# ── API ────────────────────────────────────────────────────────────────────────

func clear() -> void:
	_strokes.clear()
	_current = PackedVector2Array()
	_is_drawing = false
	queue_redraw()

func get_stroke_count() -> int:
	return _strokes.size()

func set_enabled(enabled: bool) -> void:
	_enabled = enabled

# Score le tracé contre le nombre de traits attendu et la couverture spatiale.
# Retourne un float entre 0.0 et 1.0.
func compute_score(expected_stroke_count: int) -> float:
	if _strokes.is_empty():
		return 0.0

	# 1. Score nombre de traits (tolérant : ±50%)
	var stroke_score : float = 0.0
	if expected_stroke_count > 0:
		var diff   : int = abs(_strokes.size() - expected_stroke_count)
		var ratio  : float = float(diff) / float(expected_stroke_count)
		stroke_score = clamp(1.0 - ratio, 0.0, 1.0)
	else:
		stroke_score = 1.0   # Pas de référence : on ne pénalise pas

	# 2. Score couverture spatiale (le tracé occupe-t-il une bonne portion de la zone ?)
	var min_x :=  INF
	var min_y :=  INF
	var max_x := -INF
	var max_y := -INF
	for stroke in _strokes:
		for p in stroke:
			min_x = min(min_x, p.x)
			min_y = min(min_y, p.y)
			max_x = max(max_x, p.x)
			max_y = max(max_y, p.y)
	var bbox_w   : float = max(0.0, max_x - min_x)
	var bbox_h   : float = max(0.0, max_y - min_y)
	var bbox_area: float = bbox_w * bbox_h
	var area     : float = size.x * size.y
	var coverage_ratio : float = bbox_area / max(1.0, area)
	# Idéal entre 25% et 75%, score linéaire jusqu'à 0.5 puis plateau
	var coverage_score : float = clamp(coverage_ratio / 0.5, 0.0, 1.0)

	# 3. Longueur totale (pour pénaliser les gribouillis trop courts)
	var total_length : float = 0.0
	for stroke in _strokes:
		for i in range(1, stroke.size()):
			total_length += stroke[i - 1].distance_to(stroke[i])
	var length_score : float = clamp(total_length / (size.x * 1.5), 0.0, 1.0)

	return stroke_score * 0.5 + coverage_score * 0.3 + length_score * 0.2
