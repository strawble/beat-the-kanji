extends Node2D

# Main combat scene. Integrates:
# - MCQ questions with timer
# - hint system
# - parry overlay (kanji drawing — every ~20s between questions)
# - advanced stats: crit, dodge, regen
# - NavBar integration

const VICTORY_SCENE := preload("res://scenes/victory/VictoryScreen.tscn")
const COMBAT_TIMER_SCRIPT := preload("res://scenes/game_world/CombatTimer.gd")
const KANJI_DRAWING_SCENE := preload("res://scenes/kanji_drawing/KanjiDrawing.tscn")

# ── References to existing nodes ──────────────────────────────────────────────
@onready var boss_name_label : Label         = $UI/Root/VBox/BossSection/BossVBox/BossName
@onready var boss_hp_bar     : ProgressBar   = $UI/Root/VBox/BossSection/BossVBox/BossHPBar
@onready var boss_sprite     : Label         = $UI/Root/VBox/BossSection/BossVBox/BossSprite
@onready var player_hp_bar   : ProgressBar   = $UI/Root/VBox/PlayerSection/PlayerHBox/PlayerHPBar
@onready var player_hp_label : Label         = $UI/Root/VBox/PlayerSection/PlayerHBox/PlayerHPLabel
@onready var question_label  : Label         = $UI/Root/VBox/QuestionSection/QuestionVBox/QuestionLabel
@onready var answer_grid     : GridContainer = $UI/Root/VBox/QuestionSection/QuestionVBox/AnswerGrid
@onready var info_label      : Label         = $UI/Root/VBox/InfoLabel

@onready var level_label     : Label         = $UI/Root/VBox/StatsBar/StatsHBox/LevelLabel
@onready var xp_bar          : ProgressBar   = $UI/Root/VBox/StatsBar/StatsHBox/XPBar
@onready var coins_label     : Label         = $UI/Root/VBox/StatsBar/StatsHBox/CoinsLabel

@onready var levelup_overlay : PanelContainer = $UI/LevelUpOverlay
@onready var levelup_title   : Label          = $UI/LevelUpOverlay/LevelUpVBox/LevelUpTitle
@onready var levelup_sub     : Label          = $UI/LevelUpOverlay/LevelUpVBox/LevelUpSub

# Phase B nodes (added to scene — see INTEGRATION_GUIDE.md)
# If missing, created in code.
@onready var combat_timer_holder : Node = get_node_or_null("UI/Root/VBox/CombatTimerHolder")
@onready var hint_button : Button = get_node_or_null("UI/Root/VBox/QuestionSection/QuestionVBox/HintButton")
@onready var hint_label  : Label  = get_node_or_null("UI/Root/VBox/QuestionSection/QuestionVBox/HintLabel")

var combat_timer : CombatTimer
var parry_drawing : Node = null   # instance of KanjiDrawing

# ── Combat state ──────────────────────────────────────────────────────────────
var boss             : Dictionary = {}
var boss_hp          : int = 0
var player_hp        : int = 100
var player_max_hp    : int = 100

var current_question : Dictionary = {}
var awaiting_answer  : bool = false
var hint_level_used  : int  = 0

var _newly_discovered_this_fight : Array[int] = []

# Parry timer (between questions, triggers a parry every ~20s)
const PARRY_INTERVAL : float = 20.0
var _time_until_parry : float = PARRY_INTERVAL
var _in_parry : bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_combat_timer()
	_setup_hint_ui()
	_connect_buttons()
	_connect_signals()
	_setup_navbar()
	_refresh_stats_bar()
	GameManager.clear_temp_buffs()
	start_combat()

func _setup_navbar() -> void:
	NavBar.show_for_scene("combat")

func _setup_combat_timer() -> void:
	combat_timer = COMBAT_TIMER_SCRIPT.new()
	combat_timer.name = "CombatTimer"
	if combat_timer_holder:
		combat_timer_holder.add_child(combat_timer)
	else:
		var question_section := $UI/Root/VBox/QuestionSection
		var vbox := $UI/Root/VBox
		vbox.add_child(combat_timer)
		vbox.move_child(combat_timer, question_section.get_index())
	combat_timer.timeout.connect(_on_timer_timeout)

func _setup_hint_ui() -> void:
	if hint_button == null:
		var qvbox := $UI/Root/VBox/QuestionSection/QuestionVBox
		hint_button = Button.new()
		hint_button.name = "HintButton"
		hint_button.text = "💡 Hint"
		hint_button.custom_minimum_size = Vector2(0, 36)
		qvbox.add_child(hint_button)
	if hint_label == null:
		var qvbox := $UI/Root/VBox/QuestionSection/QuestionVBox
		hint_label = Label.new()
		hint_label.name = "HintLabel"
		hint_label.text = ""
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint_label.add_theme_font_size_override("font_size", 14)
		hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		qvbox.add_child(hint_label)
	hint_button.pressed.connect(_on_hint_pressed)

func _connect_buttons() -> void:
	var i := 0
	for btn in answer_grid.get_children():
		var idx := i
		btn.pressed.connect(func(): _on_answer_pressed(idx))
		i += 1

func _connect_signals() -> void:
	GameManager.leveled_up.connect(_on_leveled_up)
	GameManager.mastery_changed.connect(_on_mastery_changed)

# ── Main loop (handles parry timer) ───────────────────────────────────────────
func _process(delta: float) -> void:
	if _in_parry or boss.is_empty():
		return
	_time_until_parry -= delta
	if _time_until_parry <= 0.0:
		_trigger_parry()

# ── Stats bar ─────────────────────────────────────────────────────────────────
func _refresh_stats_bar() -> void:
	var d := GameManager.data
	level_label.text  = "Lv. %d" % d.player_level
	coins_label.text  = "%d 🪙" % d.coins
	xp_bar.max_value  = GameManager.xp_for_next_level()
	xp_bar.value      = d.xp
	xp_bar.tooltip_text = "%d / %d XP" % [d.xp, GameManager.xp_for_next_level()]

func _on_leveled_up(new_level: int) -> void:
	_refresh_stats_bar()
	_show_levelup_overlay(new_level)

func _on_mastery_changed(_kanji_id: int, _new_value: float) -> void:
	_refresh_stats_bar()

func _show_levelup_overlay(new_level: int) -> void:
	var unlocked_count := KanjiDB.get_unlocked(new_level).size() \
						- KanjiDB.get_unlocked(new_level - 1).size()
	levelup_title.text = "LEVEL UP!"
	if unlocked_count > 0:
		levelup_sub.text = "Level %d  —  %d new kanji(s) unlocked" % [new_level, unlocked_count]
	else:
		levelup_sub.text = "Level %d" % new_level
	levelup_overlay.visible = true
	await get_tree().create_timer(2.5).timeout
	levelup_overlay.visible = false

# ── Combat ────────────────────────────────────────────────────────────────────
func start_combat() -> void:
	boss          = BossGenerator.generate()
	boss_hp       = boss["max_hp"]
	player_max_hp = 100 + GameManager.get_bonus_hp()
	player_hp     = player_max_hp

	boss_hp_bar.max_value   = boss_hp
	boss_hp_bar.value       = boss_hp
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value     = player_max_hp

	boss_name_label.text = boss["name"]
	info_label.text      = ""
	_newly_discovered_this_fight.clear()
	_time_until_parry    = PARRY_INTERVAL
	_in_parry            = false

	_update_player_label()
	_refresh_stats_bar()
	_next_question()

func _next_question() -> void:
	var pool : Array = boss["kanji_pool"]
	if pool.is_empty():
		return

	var kanji        = pool[randi() % pool.size()]
	current_question  = KanjiDB.build_question(kanji)
	awaiting_answer   = true
	hint_level_used   = 0
	hint_label.text   = ""
	hint_button.disabled = false

	boss_sprite.text = kanji["character"] if current_question["type"] != "character" else "?"
	question_label.text = current_question["prompt"]
	info_label.text     = ""

	var choices = current_question["choices"]
	var buttons := answer_grid.get_children()
	for i in range(buttons.size()):
		buttons[i].text     = choices[i] if i < choices.size() else "—"
		buttons[i].disabled = false
		buttons[i].modulate = Color.WHITE
		buttons[i].visible  = true

	combat_timer.start_for_kanji(kanji["id"])

# ── Hints ─────────────────────────────────────────────────────────────────────
func _on_hint_pressed() -> void:
	if not awaiting_answer:
		return
	if hint_level_used >= 3:
		return
	hint_level_used += 1
	var kanji := KanjiDB.get_by_id(current_question["kanji_id"])
	hint_label.text = KanjiDB.build_hint(kanji, current_question["type"], hint_level_used)
	# Level 3: also eliminate 2 wrong choices
	if hint_level_used == 3:
		_eliminate_wrong_choices(2)
		hint_button.disabled = true

func _eliminate_wrong_choices(n: int) -> void:
	var buttons := answer_grid.get_children()
	var wrong : Array = []
	for btn in buttons:
		if btn.text != current_question["correct"] and btn.visible:
			wrong.append(btn)
	wrong.shuffle()
	for i in range(min(n, wrong.size())):
		wrong[i].visible = false

# ── Answer to a question ──────────────────────────────────────────────────────
func _on_answer_pressed(idx: int) -> void:
	if not awaiting_answer:
		return
	awaiting_answer = false
	combat_timer.stop()

	var buttons   := answer_grid.get_children()
	var chosen    : String = buttons[idx].text
	var correct   : String = current_question["correct"]
	var kanji_id  : int    = current_question["kanji_id"]
	var is_correct        := chosen == correct

	# Color feedback on buttons
	for i in range(buttons.size()):
		buttons[i].disabled = true
		if buttons[i].text == correct:
			buttons[i].modulate = Color(0.3, 1.0, 0.4)
		elif i == idx and not is_correct:
			buttons[i].modulate = Color(1.0, 0.3, 0.3)

	# Hint penalty: less mastery gain
	if hint_level_used > 0 and is_correct:
		GameManager.boost_mastery(kanji_id, 0.05)
	else:
		GameManager.update_mastery(kanji_id, is_correct)

	if not GameManager.is_discovered(kanji_id):
		_newly_discovered_this_fight.append(kanji_id)
	GameManager.discover_kanji(kanji_id)

	if is_correct:
		_apply_player_attack(kanji_id)
	else:
		_apply_boss_attack(correct)

	await get_tree().create_timer(1.5).timeout

	if boss_hp <= 0:
		_on_victory()
	elif player_hp <= 0:
		_on_defeat()
	else:
		_next_question()

func _on_timer_timeout() -> void:
	if not awaiting_answer:
		return
	awaiting_answer = false
	for btn in answer_grid.get_children():
		btn.disabled = true
	var correct : String = current_question["correct"]
	var kanji_id : int = current_question["kanji_id"]
	GameManager.update_mastery(kanji_id, false)
	if not GameManager.is_discovered(kanji_id):
		_newly_discovered_this_fight.append(kanji_id)
	GameManager.discover_kanji(kanji_id)
	_apply_boss_attack(correct, " (time's up)")
	await get_tree().create_timer(1.5).timeout
	if player_hp <= 0:
		_on_defeat()
	else:
		_next_question()

# ── Applying damage ───────────────────────────────────────────────────────────
func _apply_player_attack(kanji_id: int) -> void:
	var mastery     := GameManager.get_mastery(kanji_id)
	var base_damage := int(15.0 + (1.0 - mastery) * 10.0) + GameManager.get_bonus_damage()
	var is_crit     := randf() * 100.0 < GameManager.get_crit_rate()
	var dmg         := base_damage
	var crit_marker := ""
	if is_crit:
		dmg = int(base_damage * GameManager.get_crit_dmg_multiplier())
		crit_marker = "  💥 CRIT!"

	boss_hp = max(0, boss_hp - dmg)
	boss_hp_bar.value = boss_hp

	# Regeneration
	var regen := GameManager.get_hp_regen()
	if regen > 0:
		player_hp = min(player_max_hp, player_hp + regen)
		player_hp_bar.value = player_hp
		_update_player_label()

	var mastery_pct := int(GameManager.get_mastery(kanji_id) * 100)
	_show_info("✓  -%d HP to boss%s   (mastery %d%%)" % [dmg, crit_marker, mastery_pct], true)

func _apply_boss_attack(correct: String, suffix: String = "") -> void:
	# Dodge
	if randf() * 100.0 < GameManager.get_dodge_chance():
		_show_info("⟪ Dodged! ⟫  Answer was: %s%s" % [correct, suffix], true)
		return
	var dmg = max(1, boss["damage"] - GameManager.get_damage_reduction())
	player_hp = max(0, player_hp - dmg)
	player_hp_bar.value = player_hp
	_update_player_label()
	_show_info("✗  Wrong — %s   (-%d HP)%s" % [correct, dmg, suffix], false)

# ── Parry (using KanjiDrawing) ────────────────────────────────────────────────
func _trigger_parry() -> void:
	if boss.is_empty() or boss["kanji_pool"].is_empty():
		return
	_in_parry = true
	# Freeze the current question state — we'll resume after the parry
	awaiting_answer = false
	combat_timer.pause()
	# Disable answer buttons while parry is active
	for btn in answer_grid.get_children():
		btn.disabled = true

	# Pick a random kanji from the boss's pool
	var kanji : Dictionary = boss["kanji_pool"][randi() % boss["kanji_pool"].size()]

	# Instance the KanjiDrawing overlay (CanvasLayer — add to scene root, not $UI)
	parry_drawing = KANJI_DRAWING_SCENE.instantiate()
	add_child(parry_drawing)
	parry_drawing.setup(kanji, 1)
	parry_drawing.drawing_validated.connect(_on_parry_resolved)

func _on_parry_resolved(success: bool, coverage: float) -> void:
	# Cleanup overlay
	if parry_drawing:
		parry_drawing.queue_free()
		parry_drawing = null

	_in_parry = false
	_time_until_parry = PARRY_INTERVAL

	if success:
		# Counter-attack: moderate damage to boss
		var counter_dmg := 10 + int(coverage * 20)
		boss_hp = max(0, boss_hp - counter_dmg)
		boss_hp_bar.value = boss_hp
		_show_info("⚔ Counter-attack! -%d HP to boss" % counter_dmg, true)
	else:
		# Boss strikes
		var dmg = max(2, boss["damage"] * 2 - GameManager.get_damage_reduction())
		player_hp = max(0, player_hp - dmg)
		player_hp_bar.value = player_hp
		_update_player_label()
		_show_info("✗ The boss strikes! -%d HP" % dmg, false)

	if boss_hp <= 0:
		_on_victory()
		return
	if player_hp <= 0:
		_on_defeat()
		return
	# Always start a fresh question after a parry — don't resume the interrupted one
	_next_question()

# ── Victory / Defeat ──────────────────────────────────────────────────────────
func _on_victory() -> void:
	combat_timer.stop()
	awaiting_answer = false

	GameManager.add_xp(boss["xp_reward"])
	GameManager.add_coins(boss["coin_reward"])
	_refresh_stats_bar()

	var newly_discovered : Array = []
	for id in _newly_discovered_this_fight:
		var k := KanjiDB.get_by_id(id)
		if not k.is_empty():
			newly_discovered.append(k)
	_newly_discovered_this_fight.clear()

	for btn in answer_grid.get_children():
		btn.disabled = true

	var vs := VICTORY_SCENE.instantiate()
	$UI.add_child(vs)
	vs.setup(boss, newly_discovered)
	vs.continue_pressed.connect(func():
		vs.queue_free()
		start_combat()
	)

func _on_defeat() -> void:
	combat_timer.stop()
	awaiting_answer = false

	# Revive shield
	if GameManager.data.has_revive_shield:
		GameManager.data.has_revive_shield = false
		GameManager.save_game()
		player_hp = player_max_hp
		player_hp_bar.value = player_hp
		_update_player_label()
		_show_info("✨ Revival Fetish consumed! HP restored.", true)
		await get_tree().create_timer(2.0).timeout
		_next_question()
		return

	var penalty = min(GameManager.data.coins, 5)
	if penalty > 0:
		GameManager.spend_coins(penalty)
	_refresh_stats_bar()
	_show_info("✖ Defeat  -%d coins — new battle..." % penalty, false)
	question_label.text = "New battle in 3 seconds..."
	boss_sprite.text    = "✖"
	for btn in answer_grid.get_children():
		btn.text = "" ; btn.disabled = true
	GameManager.clear_temp_buffs()

	await get_tree().create_timer(3.0).timeout
	start_combat()

# ── UI helpers ────────────────────────────────────────────────────────────────
func _show_info(msg: String, positive: bool) -> void:
	info_label.text     = msg
	info_label.modulate = Color(0.3, 1.0, 0.4) if positive else Color(1.0, 0.3, 0.3)

func _update_player_label() -> void:
	player_hp_label.text = "HP: %d / %d" % [player_hp, player_max_hp]

# ── Dev shortcuts ─────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			GameManager.add_xp(50)
			_refresh_stats_bar()
		elif event.keycode == KEY_R:
			GameManager.reset_save()
			start_combat()
			_refresh_stats_bar()
		elif event.keycode == KEY_C:
			GameManager.add_coins(200)
			_refresh_stats_bar()
		elif event.keycode == KEY_H:
			_try_use_potion()
		elif event.keycode == KEY_P:
			# Force a parry (for testing)
			if not _in_parry and not boss.is_empty():
				_trigger_parry()

func _try_use_potion() -> void:
	for item_id in [17, 16]:   # Master's Tea, Potion of Clarity
		if GameManager.has_item(item_id):
			var item := ItemDB.get_by_id(item_id)
			GameManager.use_consumable(item_id)
			var stat : String = item["effects"][0]["stat"]
			if stat == "heal_full":
				player_hp = player_max_hp
			elif stat == "heal":
				player_hp = min(player_max_hp, player_hp + int(item["effects"][0]["value"]))
			player_hp_bar.value = player_hp
			_update_player_label()
			_show_info("🧪 %s used!" % item["name"], true)
			return
	_show_info("No potion in inventory", false)
