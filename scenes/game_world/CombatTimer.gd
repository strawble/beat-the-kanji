extends PanelContainer
class_name CombatTimer

# Response timer during combat. Self-contained: Label + ProgressBar + internal Timer.
# Emits `timeout` when the delay expires, `tick(remaining)` each frame.

signal timeout
signal tick(remaining: float)

const BASE_TIME : float = 8.0
const MIN_TIME  : float = 5.0
const MAX_TIME  : float = 12.0

@onready var bar   : ProgressBar = $VBox/Bar
@onready var label : Label       = $VBox/Label

var _remaining : float = 0.0
var _running   : bool  = false
var _total     : float = BASE_TIME

func _ready() -> void:
	# If the scene wasn't configured properly, build UI in code as fallback.
	if not has_node("VBox"):
		_build_ui_fallback()
	custom_minimum_size = Vector2(0, 60)
	stop()

func _build_ui_fallback() -> void:
	var v := VBoxContainer.new()
	v.name = "VBox"
	add_child(v)
	var l := Label.new()
	l.name = "Label"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = "0.0 s"
	v.add_child(l)
	var b := ProgressBar.new()
	b.name = "Bar"
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 18)
	v.add_child(b)
	label = l
	bar = b

func _process(delta: float) -> void:
	if not _running:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		_remaining = 0.0
		_running = false
		bar.value = 0
		label.text = "Time's up!"
		emit_signal("timeout")
		return
	bar.value = _remaining
	label.text = "%.1f s" % _remaining
	emit_signal("tick", _remaining)

# ── API ────────────────────────────────────────────────────────────────────────

# Starts the timer for a given kanji. The more mastered the kanji, the less time.
func start_for_kanji(kanji_id: int) -> void:
	var mastery := GameManager.get_mastery(kanji_id)
	# mastery 0 → 12s, mastery 1 → 5s
	_total = lerp(MAX_TIME, MIN_TIME, mastery) + GameManager.temp_timer_bonus
	# Consume a use of the timer buff
	if GameManager.temp_timer_uses > 0:
		GameManager.temp_timer_uses -= 1
		if GameManager.temp_timer_uses == 0:
			GameManager.temp_timer_bonus = 0.0
	_remaining = _total
	bar.max_value = _total
	bar.value = _total
	label.text = "%.1f s" % _remaining
	_running = true
	visible = true

func stop() -> void:
	_running = false
	visible = false

func pause() -> void:
	_running = false

func resume() -> void:
	if _remaining > 0.0:
		_running = true
