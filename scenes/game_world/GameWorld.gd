extends Node2D

const VICTORY_SCENE := preload("res://scenes/victory/VictoryScreen.tscn")

# ── Constantes ─────────────────────────────────────────────────────────────────
const QUESTION_TIMEOUT  : float = 10.0
const PARADE_TIMEOUT    : float = 15.0   # temps pour parer l'attaque du boss
const CORRECT_TO_MASTER : int   = 3
const BASE_PLAYER_HP    : int   = 100
const PHASE1_BOSS_HP    : int   = 9      # 3 kanjis × 3 étoiles

# Dégâts Phase 1 : mauvaise réponse = 1/9 des PV joueur
const PHASE1_PLAYER_HP_FRACTION : int = 9

# Dégâts Phase 2
const DRAW_BASE_DMG        : int = 25   # tracé réussi
const SPELL_DMG_2_KANJIS   : int = 4    # sort 2 kanjis
const SPELL_DMG_3_KANJIS   : int = 5    # sort 3 kanjis
const BOSS_ATTACK_DMG      : int = 20   # attaque brute du boss (avant parade)

enum CombatPhase { PHASE1_LEARNING, PHASE2_COMBAT }
enum Phase2Mode  { CHOOSING, CASTING_SPELL, PARRYING }

# ── Nœuds existants ────────────────────────────────────────────────────────────
@onready var boss_name_label  : Label         = $UI/Root/VBox/BossSection/BossVBox/BossName
@onready var boss_hp_bar      : ProgressBar   = $UI/Root/VBox/BossSection/BossVBox/BossHPBar
@onready var boss_sprite      : Label         = $UI/Root/VBox/BossSection/BossVBox/BossSprite
@onready var boss_vbox        : VBoxContainer = $UI/Root/VBox/BossSection/BossVBox
@onready var player_hp_bar    : ProgressBar   = $UI/Root/VBox/PlayerSection/PlayerHBox/PlayerHPBar
@onready var player_hp_label  : Label         = $UI/Root/VBox/PlayerSection/PlayerHBox/PlayerHPLabel
@onready var question_label   : Label         = $UI/Root/VBox/QuestionSection/QuestionVBox/QuestionLabel
@onready var answer_grid      : GridContainer = $UI/Root/VBox/QuestionSection/QuestionVBox/AnswerGrid
@onready var info_label       : Label         = $UI/Root/VBox/InfoLabel
@onready var level_label      : Label         = $UI/Root/VBox/StatsBar/StatsHBox/LevelLabel
@onready var xp_bar           : ProgressBar   = $UI/Root/VBox/StatsBar/StatsHBox/XPBar
@onready var coins_label      : Label         = $UI/Root/VBox/StatsBar/StatsHBox/CoinsLabel
@onready var dex_button       : Button        = $UI/Root/VBox/StatsBar/StatsHBox/DexButton
@onready var shop_button      : Button        = $UI/Root/VBox/StatsBar/StatsHBox/ShopButton
@onready var levelup_overlay  : PanelContainer = $UI/LevelUpOverlay
@onready var levelup_title    : Label          = $UI/LevelUpOverlay/LevelUpVBox/LevelUpTitle
@onready var levelup_sub      : Label          = $UI/LevelUpOverlay/LevelUpVBox/LevelUpSub
@onready var question_section : Control        = $UI/Root/VBox/QuestionSection

# ── Nœuds créés dynamiquement ─────────────────────────────────────────────────
var timer_bar          : ProgressBar    = null
var phase_label        : Label          = null
var kanji_status_box   : HBoxContainer  = null
var phase2_boss_hp_bar : ProgressBar    = null   # barre de vie Phase 2, dans BossVBox
var phase2_boss_hp_row : HBoxContainer  = null   # conteneur (pour show/hide)
var phase2_panel       : PanelContainer = null
var spell_btn          : Button         = null
var draw_btn           : Button         = null
var confirm_overlay    : PanelContainer = null

# ── État ───────────────────────────────────────────────────────────────────────
var boss            : Dictionary = {}
var boss_hp_phase1  : int = 0
var boss_hp_phase2  : int = 0
var boss_current_hp : int = 0
var player_hp       : int = BASE_PLAYER_HP
var player_max_hp   : int = BASE_PLAYER_HP

var current_phase    : CombatPhase = CombatPhase.PHASE1_LEARNING
var phase2_mode      : Phase2Mode  = Phase2Mode.CHOOSING
var current_question : Dictionary  = {}
var awaiting_answer  : bool        = false

var battle_correct_counts        : Dictionary = {}
var drawing_attempt_counts       : Dictionary = {}
var _newly_discovered_this_fight : Array[int] = []

# Parade : dégâts boss en attente pendant la phase de parade
var _pending_boss_dmg : int = 0

var _timer_value  : float = QUESTION_TIMEOUT
var _timer_active : bool  = false

# ═══════════════════════════════════════════════════════════════════════════════
# ── INIT ───────────────────────────────────────════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_dynamic_ui()
	_connect_answer_buttons()
	GameManager.leveled_up.connect(_on_leveled_up)
	GameManager.mastery_changed.connect(_on_mastery_changed)
	dex_button.pressed.connect(func(): GameManager.go_to("res://scenes/kanji_dex/KanjiDex.tscn"))
	shop_button.pressed.connect(func(): GameManager.go_to("res://scenes/shop/Shop.tscn"))
	_refresh_stats_bar()
	start_combat()

func _connect_answer_buttons() -> void:
	var i : int = 0
	for btn in answer_grid.get_children():
		var idx : int = i
		(btn as Button).pressed.connect(func(): _on_answer_pressed(idx))
		i += 1

func _build_dynamic_ui() -> void:
	var vbox : VBoxContainer = $UI/Root/VBox
	var boss_section : Control = $UI/Root/VBox/BossSection

	# ── Barre de vie Phase 2 — insérée dans BossVBox juste sous BossName ──
	phase2_boss_hp_row = HBoxContainer.new()
	phase2_boss_hp_row.visible = false
	phase2_boss_hp_row.add_theme_constant_override("separation", 6)
	# Insère après BossName (index 0), avant BossHPBar (index 1)
	boss_vbox.add_child(phase2_boss_hp_row)
	boss_vbox.move_child(phase2_boss_hp_row, 1)   # 0=BossName, 1=ici, 2=BossHPBar, 3=BossSprite

	var p2lbl := Label.new()
	p2lbl.text = "⚔️ Phase 2"
	p2lbl.add_theme_font_size_override("font_size", 12)
	phase2_boss_hp_row.add_child(p2lbl)

	phase2_boss_hp_bar = ProgressBar.new()
	phase2_boss_hp_bar.custom_minimum_size   = Vector2(0, 20)
	phase2_boss_hp_bar.show_percentage       = false
	phase2_boss_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase2_boss_hp_bar.modulate              = Color(1.0, 0.45, 0.1)
	phase2_boss_hp_row.add_child(phase2_boss_hp_bar)

	# ── Timer ──
	timer_bar = ProgressBar.new()
	timer_bar.custom_minimum_size = Vector2(0, 14)
	timer_bar.max_value           = QUESTION_TIMEOUT
	timer_bar.value               = QUESTION_TIMEOUT
	timer_bar.show_percentage     = false
	vbox.add_child(timer_bar)
	vbox.move_child(timer_bar, question_section.get_index())

	# ── Label de phase ──
	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(phase_label)
	vbox.move_child(phase_label, 1)

	# ── Étoiles de maîtrise ──
	kanji_status_box = HBoxContainer.new()
	kanji_status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	kanji_status_box.add_theme_constant_override("separation", 20)
	vbox.add_child(kanji_status_box)
	vbox.move_child(kanji_status_box, boss_section.get_index() + 1)

	# ── Panel Phase 2 ──
	phase2_panel = PanelContainer.new()
	phase2_panel.visible = false
	vbox.add_child(phase2_panel)

	var p2v := VBoxContainer.new()
	p2v.add_theme_constant_override("separation", 12)
	phase2_panel.add_child(p2v)

	var p2title := Label.new()
	p2title.text = "⚔️  Choisissez votre attaque !"
	p2title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2title.add_theme_font_size_override("font_size", 16)
	p2v.add_child(p2title)

	var p2h := HBoxContainer.new()
	p2h.add_theme_constant_override("separation", 12)
	p2v.add_child(p2h)

	spell_btn = Button.new()
	spell_btn.text = "🔮  Sort"
	spell_btn.custom_minimum_size   = Vector2(0, 60)
	spell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spell_btn.pressed.connect(_on_spell_btn_pressed)
	p2h.add_child(spell_btn)

	draw_btn = Button.new()
	draw_btn.text = "✍️  Tracer (attaque)"
	draw_btn.custom_minimum_size   = Vector2(0, 60)
	draw_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_btn.pressed.connect(_on_draw_attack_pressed)
	p2h.add_child(draw_btn)

	# ── Bouton Abandonner ──
	var quit_btn := Button.new()
	quit_btn.text = "🏠  Abandonner"
	quit_btn.custom_minimum_size   = Vector2(0, 36)
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

	# ── Dialogue confirmation ──
	confirm_overlay = PanelContainer.new()
	confirm_overlay.set_anchors_preset(Control.PRESET_CENTER)
	confirm_overlay.visible = false
	$UI.add_child(confirm_overlay)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 16)
	confirm_overlay.add_child(cv)

	var clbl := Label.new()
	clbl.text = "Abandonner le niveau ?"
	clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clbl.add_theme_font_size_override("font_size", 18)
	cv.add_child(clbl)

	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 20)
	cv.add_child(ch)

	var yes_btn := Button.new()
	yes_btn.text = "✅  Oui, quitter"
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.pressed.connect(_confirm_quit)
	ch.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "❌  Continuer"
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_btn.pressed.connect(func(): confirm_overlay.visible = false)
	ch.add_child(no_btn)

func _on_quit_pressed() -> void:
	_timer_active = false
	confirm_overlay.visible = true

func _confirm_quit() -> void:
	confirm_overlay.visible = false
	GameManager.go_to("res://scenes/main_menu/main_menu.tscn")

# ── Stats bar ──────────────────────────────────────────────────────────────────
func _refresh_stats_bar() -> void:
	var d : PlayerData = GameManager.data
	level_label.text = "Niv. %d" % d.player_level
	coins_label.text = "%d 🪙" % d.coins
	xp_bar.max_value = GameManager.xp_for_next_level()
	xp_bar.value     = d.xp

func _get_player_max_hp() -> int:
	return BASE_PLAYER_HP + GameManager.get_bonus_hp()

func _on_leveled_up(new_level: int) -> void:
	_refresh_stats_bar()
	_show_levelup_overlay(new_level)

func _on_mastery_changed(_id: int, _v: float) -> void:
	_refresh_stats_bar()

func _show_levelup_overlay(new_level: int) -> void:
	var prev : int = KanjiDB.get_unlocked(new_level - 1).size()
	var curr : int = KanjiDB.get_unlocked(new_level).size()
	levelup_title.text = "LEVEL UP !"
	levelup_sub.text   = "Niveau %d%s" % [new_level,
		("  —  %d nouveau(x) kanji(s) !" % (curr - prev)) if curr > prev else ""]
	levelup_overlay.visible = true
	await get_tree().create_timer(2.5).timeout
	levelup_overlay.visible = false

# ═══════════════════════════════════════════════════════════════════════════════
# ── COMBAT ─────────────────────────────────────────────────════════════════════
# ═══════════════════════════════════════════════════════════════════════════════

func start_combat() -> void:
	_newly_discovered_this_fight.clear()
	battle_correct_counts.clear()
	drawing_attempt_counts.clear()
	_pending_boss_dmg = 0

	boss          = BossGenerator.generate()
	player_max_hp = _get_player_max_hp()
	player_hp     = player_max_hp

	boss_hp_phase1 = PHASE1_BOSS_HP
	boss_hp_phase2 = boss["max_hp"]

	boss_hp_bar.max_value   = boss_hp_phase1
	boss_hp_bar.value       = boss_hp_phase1
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value     = player_max_hp
	boss_name_label.text    = boss["name"]
	info_label.text         = ""

	phase2_boss_hp_bar.max_value = boss_hp_phase2
	phase2_boss_hp_bar.value     = boss_hp_phase2
	phase2_boss_hp_row.visible   = false

	for k in boss["kanji_pool"]:
		battle_correct_counts[int(k["id"])]  = 0
		drawing_attempt_counts[int(k["id"])] = 0

	_update_player_label()
	_refresh_stats_bar()
	_enter_phase1()

# ═══════════════════════════════════════════════════════════════════════════════
# ── PHASE 1 ────────────────────────────────────────────════════════════════════
# ═══════════════════════════════════════════════════════════════════════════════

func _enter_phase1() -> void:
	current_phase = CombatPhase.PHASE1_LEARNING
	phase_label.text         = "⚡ Phase 1 — Apprentissage"
	phase2_panel.visible     = false
	question_section.visible = true
	timer_bar.visible        = true
	boss_hp_bar.max_value    = boss_hp_phase1
	boss_current_hp          = boss_hp_phase1
	boss_hp_bar.value        = boss_hp_phase1
	boss_sprite.text         = "👾"
	_rebuild_kanji_status()
	_next_question()

func _rebuild_kanji_status() -> void:
	while kanji_status_box.get_child_count() > 0:
		var child : Node = kanji_status_box.get_child(0)
		kanji_status_box.remove_child(child)
		child.queue_free()
	for k in boss["kanji_pool"]:
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		var char_lbl := Label.new()
		char_lbl.text = k["character"]
		char_lbl.add_theme_font_size_override("font_size", 30)
		char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(char_lbl)
		var count    : int  = battle_correct_counts.get(int(k["id"]), 0)
		var mastered : bool = count >= CORRECT_TO_MASTER
		var stars    : String = ""
		for i in range(CORRECT_TO_MASTER):
			stars += "★" if i < count else "☆"
		var star_lbl := Label.new()
		star_lbl.text = stars
		star_lbl.add_theme_font_size_override("font_size", 16)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.modulate = Color(0.3, 1.0, 0.4) if mastered else Color(1.0, 1.0, 0.4)
		vb.add_child(star_lbl)
		kanji_status_box.add_child(vb)

func _all_kanjis_mastered() -> bool:
	for k in boss["kanji_pool"]:
		if battle_correct_counts.get(int(k["id"]), 0) < CORRECT_TO_MASTER:
			return false
	return true

func _pick_unmastered_kanji() -> Dictionary:
	var unmastered : Array = []
	for k in boss["kanji_pool"]:
		if battle_correct_counts.get(int(k["id"]), 0) < CORRECT_TO_MASTER:
			unmastered.append(k)
	if unmastered.is_empty(): return {}
	return unmastered[randi() % unmastered.size()]

func _next_question() -> void:
	var kanji : Dictionary = _pick_unmastered_kanji()
	if kanji.is_empty():
		_enter_phase2()
		return
	current_question = KanjiDB.build_question(kanji, boss["kanji_pool"])
	awaiting_answer  = true
	boss_sprite.text    = kanji["character"] if current_question["type"] != "character" else "?"
	question_label.text = current_question["prompt"]
	info_label.text     = ""
	var choices : Array = current_question["choices"]
	var buttons : Array = answer_grid.get_children()
	for i in range(buttons.size()):
		(buttons[i] as Button).text     = choices[i] if i < choices.size() else "?"
		(buttons[i] as Button).disabled = false
		(buttons[i] as Button).modulate = Color.WHITE
	_timer_value        = QUESTION_TIMEOUT
	timer_bar.max_value = QUESTION_TIMEOUT
	timer_bar.value     = QUESTION_TIMEOUT
	_timer_active       = true

func _process(delta: float) -> void:
	if not _timer_active: return
	_timer_value -= delta
	timer_bar.value = max(0.0, _timer_value)
	var ratio : float = _timer_value / timer_bar.max_value
	if   ratio > 0.5:  timer_bar.modulate = Color(0.3, 1.0, 0.4)
	elif ratio > 0.25: timer_bar.modulate = Color(1.0, 0.75, 0.2)
	else:              timer_bar.modulate = Color(1.0, 0.3, 0.3)
	if _timer_value <= 0.0:
		_timer_active = false
		_on_timeout()

func _on_timeout() -> void:
	if not awaiting_answer: return
	awaiting_answer = false
	_disable_answer_buttons()
	# Phase 1 : timeout = même pénalité que mauvaise réponse
	var dmg : int = player_max_hp / PHASE1_PLAYER_HP_FRACTION
	player_hp = max(0, player_hp - dmg)
	player_hp_bar.value = player_hp
	_update_player_label()
	_show_info("⏱  Temps écoulé !  Réponse : %s   (−%d PV)" % [current_question["correct"], dmg], false)
	await get_tree().create_timer(1.8).timeout
	if player_hp <= 0: _on_defeat()
	else:              _next_question()

func _on_answer_pressed(idx: int) -> void:
	if not awaiting_answer: return
	if current_phase == CombatPhase.PHASE2_COMBAT:
		_handle_phase2_spell_answer(idx)
	else:
		_handle_phase1_answer(idx)

func _handle_phase1_answer(idx: int) -> void:
	awaiting_answer = false
	_timer_active   = false
	var buttons    : Array  = answer_grid.get_children()
	var chosen     : String = current_question["choices"][idx]
	var correct    : String = current_question["correct"]
	var kanji_id   : int    = int(current_question["kanji_id"])
	var is_correct : bool   = (chosen == correct)
	for i in range(buttons.size()):
		(buttons[i] as Button).disabled = true
		if current_question["choices"][i] == correct:
			(buttons[i] as Button).modulate = Color(0.3, 1.0, 0.4)
		elif i == idx and not is_correct:
			(buttons[i] as Button).modulate = Color(1.0, 0.3, 0.3)
	GameManager.update_mastery(kanji_id, is_correct)
	if not GameManager.is_discovered(kanji_id):
		_newly_discovered_this_fight.append(kanji_id)
	GameManager.discover_kanji(kanji_id)
	if is_correct:
		battle_correct_counts[kanji_id] = battle_correct_counts.get(kanji_id, 0) + 1
		var count    : int    = battle_correct_counts[kanji_id]
		var char_str : String = KanjiDB.get_by_id(kanji_id).get("character", "")
		boss_current_hp   = max(0, boss_current_hp - 1)
		boss_hp_bar.value = boss_current_hp
		if count >= CORRECT_TO_MASTER:
			_show_info("✓  %s maîtrisé ! ★★★" % char_str, true)
		else:
			_show_info("✓  Bonne réponse !  (%d/3 ★  %s)" % [count, char_str], true)
	else:
		# Mauvaise réponse = −1/9 des PV joueur
		var dmg : int = player_max_hp / PHASE1_PLAYER_HP_FRACTION
		player_hp = max(0, player_hp - dmg)
		player_hp_bar.value = player_hp
		_update_player_label()
		_show_info("✗  Faux — la réponse était : %s   (−%d PV)" % [correct, dmg], false)
	_rebuild_kanji_status()
	await get_tree().create_timer(1.5).timeout
	if player_hp <= 0:
		_on_defeat()
		return
	if _all_kanjis_mastered():
		_enter_phase2()
		return
	_next_question()

# ═══════════════════════════════════════════════════════════════════════════════
# ── PHASE 2 ────────────────────────────────────────────═══════════════════════
# ═══════════════════════════════════════════════════════════════════════════════

func _enter_phase2() -> void:
	current_phase = CombatPhase.PHASE2_COMBAT
	_timer_active = false
	timer_bar.visible        = false
	question_section.visible = false
	phase2_panel.visible     = true
	phase2_mode              = Phase2Mode.CHOOSING
	boss_sprite.text         = "👹"
	# Barre Phase 1 à 0 (vaincue), barre Phase 2 à plein
	boss_hp_bar.value            = 0
	boss_current_hp              = boss_hp_phase2
	phase2_boss_hp_bar.max_value = boss_hp_phase2
	phase2_boss_hp_bar.value     = boss_hp_phase2
	phase2_boss_hp_row.visible   = true
	phase_label.text = "⚔️  Phase 2 — Combat Final !"
	_show_info("✨  Kanjis maîtrisés — passez à l'attaque !", true)
	_refresh_phase2_ui()

func _refresh_phase2_ui() -> void:
	var available : Array = SpellDB.get_available_spells()
	spell_btn.disabled = available.is_empty()
	spell_btn.text     = "🔮  Sort (%d dispo)" % available.size()

# ── Attaque : Sort ─────────────────────────────────────────────────────────────

func _on_spell_btn_pressed() -> void:
	phase2_mode = Phase2Mode.CASTING_SPELL
	_show_spell_selection_ui()

func _show_spell_selection_ui() -> void:
	question_section.visible = true
	phase2_panel.visible     = false
	question_label.text      = "Choisissez un sort :"
	var available : Array = SpellDB.get_available_spells()
	var buttons   : Array = answer_grid.get_children()
	for i in range(buttons.size()):
		var btn : Button = buttons[i] as Button
		if i < available.size():
			var sp  : Dictionary = available[i]
			var dmg : int = _compute_spell_damage(sp)
			btn.text     = "%s  (%d kanjis · %d dégâts)" % [sp["name"], (sp["kanji_ids"] as Array).size(), dmg]
			btn.disabled = false
			btn.modulate = Color.WHITE
		else:
			btn.text = "" ; btn.disabled = true ; btn.modulate = Color.WHITE
	awaiting_answer = true

func _handle_phase2_spell_answer(idx: int) -> void:
	if phase2_mode != Phase2Mode.CASTING_SPELL: return
	awaiting_answer = false
	_disable_answer_buttons()
	var available : Array = SpellDB.get_available_spells()
	if idx >= available.size():
		question_section.visible = false
		phase2_panel.visible     = true
		_refresh_phase2_ui()
		return
	var spell : Dictionary = available[idx]
	var dmg   : int        = _compute_spell_damage(spell)
	boss_current_hp = max(0, boss_current_hp - dmg)
	phase2_boss_hp_bar.value = boss_current_hp
	question_section.visible = false
	phase2_panel.visible     = true
	_show_info("🔮  %s — %s  (−%d PV !)" % [spell["name"], spell["description"], dmg], true)
	await get_tree().create_timer(1.5).timeout
	if boss_current_hp <= 0:
		_on_victory()
		return
	# Après l'attaque du joueur → contre-attaque du boss → parade
	_boss_attacks_then_parade()

# ── Attaque : Tracé offensif ───────────────────────────────────────────────────

func _on_draw_attack_pressed() -> void:
	phase2_mode = Phase2Mode.CHOOSING
	_launch_drawing_scene(false)   # false = mode offensif

# ── Parade (après contre-attaque boss) ────────────────────────────────────────

func _boss_attacks_then_parade() -> void:
	# Le boss annonce son attaque
	_pending_boss_dmg = BOSS_ATTACK_DMG
	var kanji_for_parade : Dictionary = boss["kanji_pool"][randi() % boss["kanji_pool"].size()]
	_show_info("👹  Attaque du boss ! Tracez %s pour parer ! (15s)" % kanji_for_parade["character"], false)
	phase2_panel.visible = false
	await get_tree().create_timer(1.0).timeout
	# Lance le tracé en mode parade
	_launch_drawing_scene(true, kanji_for_parade)

func _launch_drawing_scene(is_parade: bool, forced_kanji: Dictionary = {}) -> void:
	var kanji : Dictionary
	if is_parade and not forced_kanji.is_empty():
		kanji = forced_kanji
	else:
		kanji = boss["kanji_pool"][randi() % boss["kanji_pool"].size()]

	var kid         : int = int(kanji["id"])
	var attempt_num : int = drawing_attempt_counts.get(kid, 0) + 1
	if not is_parade:
		drawing_attempt_counts[kid] = attempt_num   # incrémente seulement en offensif

	var drawing_scene := load("res://scenes/kanji_drawing/KanjiDrawing.tscn").instantiate() as Control
	drawing_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	drawing_scene.name = "KanjiDrawingOverlay"

	# En parade : timer 15s et label spécifique
	if is_parade:
		drawing_scene.set_meta("parade_mode", true)
		drawing_scene.set_meta("parade_timeout", PARADE_TIMEOUT)

	$UI.add_child(drawing_scene)
	drawing_scene.setup(kanji, attempt_num)

	drawing_scene.drawing_validated.connect(
		func(success: bool, coverage: float):
			drawing_scene.queue_free()
			if is_parade:
				_resolve_parade(coverage)
			else:
				_resolve_attack(success, coverage),
		CONNECT_ONE_SHOT
	)

# Résoudre une attaque de tracé (mode offensif)
func _resolve_attack(success: bool, coverage: float) -> void:
	phase2_panel.visible = true
	if success:
		var dmg : int = _compute_drawing_damage(coverage)
		boss_current_hp = max(0, boss_current_hp - dmg)
		phase2_boss_hp_bar.value = boss_current_hp
		_show_info("⚔️  Attaque du samouraï !  (−%d PV !)" % dmg, true)
	else:
		# Tracé raté : attaque manquée + le boss contre-attaque
		_show_info("✗  Tracé raté — attaque manquée !", false)
		await get_tree().create_timer(0.8).timeout
		_boss_attacks_then_parade()
		return
	await get_tree().create_timer(1.5).timeout
	if boss_current_hp <= 0:
		_on_victory()
		return
	# Tracé réussi → boss contre-attaque quand même
	_boss_attacks_then_parade()

# Résoudre la parade
func _resolve_parade(coverage: float) -> void:
	# coverage ∈ [0.0, 1.0] : proportion de la zone couverte
	# 0.0 = aucune parade → dégâts pleins
	# 1.0 = parade parfaite → 0 dégâts
	var dmg_taken : int = int(_pending_boss_dmg * (1.0 - coverage))
	_pending_boss_dmg = 0
	phase2_panel.visible = true

	if dmg_taken == 0:
		_show_info("🛡️  Parade parfaite ! Aucun dégât !", true)
	elif coverage > 0.5:
		_show_info("🛡️  Parade partielle — (−%d PV)" % dmg_taken, false)
	else:
		_show_info("💥  Parade ratée — (−%d PV)" % dmg_taken, false)

	player_hp = max(0, player_hp - dmg_taken)
	player_hp_bar.value = player_hp
	_update_player_label()

	await get_tree().create_timer(1.5).timeout
	if player_hp <= 0:
		_on_defeat()
		return
	# Retour au choix d'action
	phase2_mode = Phase2Mode.CHOOSING
	_refresh_phase2_ui()

# ── Calculs de dégâts ─────────────────────────────────────────────────────────

func _compute_spell_damage(spell: Dictionary) -> int:
	var nb : int = (spell["kanji_ids"] as Array).size()
	var base : int = SPELL_DMG_2_KANJIS if nb <= 2 else SPELL_DMG_3_KANJIS
	return base + GameManager.get_bonus_damage()

func _compute_drawing_damage(coverage: float) -> int:
	# Proportionnel à la qualité du tracé
	return int(DRAW_BASE_DMG * coverage) + GameManager.get_bonus_damage()

# ═══════════════════════════════════════════════════════════════════════════════
# ── VICTOIRE / DÉFAITE ─────────────────────────────────────────════════════════
# ═══════════════════════════════════════════════════════════════════════════════

func _on_victory() -> void:
	_timer_active = false
	GameManager.add_xp(boss["xp_reward"])
	GameManager.add_coins(boss["coin_reward"])
	_refresh_stats_bar()
	var newly : Array = []
	for kid in _newly_discovered_this_fight:
		var k : Dictionary = KanjiDB.get_by_id(kid)
		if not k.is_empty(): newly.append(k)
	_newly_discovered_this_fight.clear()
	var vs := VICTORY_SCENE.instantiate()
	$UI.add_child(vs)
	vs.setup(boss, newly)
	vs.continue_pressed.connect(func():
		vs.queue_free()
		GameManager.go_to("res://scenes/main_menu/main_menu.tscn")
	)
	_disable_answer_buttons()

func _on_defeat() -> void:
	_timer_active = false
	var penalty : int = min(GameManager.data.coins, 5)
	if penalty > 0: GameManager.spend_coins(penalty)
	_refresh_stats_bar()
	_show_info("✖  Défaite !  −%d pièces…" % penalty, false)
	question_label.text      = "Retour au menu dans 3 secondes…"
	boss_sprite.text         = "✖"
	phase2_panel.visible     = false
	question_section.visible = true
	_disable_answer_buttons()
	await get_tree().create_timer(3.0).timeout
	GameManager.go_to("res://scenes/main_menu/main_menu.tscn")

# ── Helpers ────────────────────────────────────────────────────────────────────

func _disable_answer_buttons() -> void:
	for btn in answer_grid.get_children():
		(btn as Button).disabled = true

func _show_info(msg: String, positive: bool) -> void:
	info_label.text     = msg
	info_label.modulate = Color(0.3, 1.0, 0.4) if positive else Color(1.0, 0.3, 0.3)

func _update_player_label() -> void:
	player_hp_label.text = "PV : %d / %d" % [player_hp, _get_player_max_hp()]

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and (event as InputEventKey).pressed): return
	var key : int = (event as InputEventKey).keycode
	if key == KEY_T: GameManager.add_xp(50) ; _refresh_stats_bar()
	elif key == KEY_C: GameManager.add_coins(50) ; _refresh_stats_bar()
	elif key == KEY_R:
		GameManager.reset_save()
		GameManager.go_to("res://scenes/main_menu/main_menu.tscn")
	elif key == KEY_M and current_phase == CombatPhase.PHASE1_LEARNING and not awaiting_answer:
		for k in boss["kanji_pool"]:
			battle_correct_counts[int(k["id"])] = CORRECT_TO_MASTER
		boss_current_hp = 0 ; boss_hp_bar.value = 0
		_rebuild_kanji_status()
		_timer_active = false
		_enter_phase2()
