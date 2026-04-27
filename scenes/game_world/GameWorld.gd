extends Node2D

const VICTORY_SCENE := preload("res://scenes/victory/VictoryScreen.tscn")

# ── Références ────────────────────────────────────────────────────────────────
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
@onready var dex_button : Button = $UI/Root/VBox/StatsBar/StatsHBox/DexButton
@onready var shop_button : Button = $UI/Root/VBox/StatsBar/StatsHBox/ShopButton

@onready var levelup_overlay : PanelContainer = $UI/LevelUpOverlay
@onready var levelup_title   : Label          = $UI/LevelUpOverlay/LevelUpVBox/LevelUpTitle
@onready var levelup_sub     : Label          = $UI/LevelUpOverlay/LevelUpVBox/LevelUpSub

# ── État du combat ─────────────────────────────────────────────────────────────
var boss             : Dictionary = {}
var boss_hp          : int = 0
var player_hp        : int = 100
var player_max_hp : int = 100

var current_question : Dictionary = {}
var awaiting_answer  : bool = false
var _newly_discovered_this_fight : Array[int] = []

# ── Démarrage ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_connect_buttons()
	_connect_signals()
	_refresh_stats_bar()
	start_combat()
	dex_button.pressed.connect(_on_dex_pressed)
	shop_button.pressed.connect(func(): GameManager.go_to("res://scenes/shop/Shop.tscn"))

func _connect_buttons() -> void:
	var i := 0
	for btn in answer_grid.get_children():
		var idx := i
		btn.pressed.connect(func(): _on_answer_pressed(idx))
		i += 1

func _connect_signals() -> void:
	GameManager.leveled_up.connect(_on_leveled_up)
	GameManager.mastery_changed.connect(_on_mastery_changed)

# ── Barre de stats ─────────────────────────────────────────────────────────────
func _refresh_stats_bar() -> void:
	var d = GameManager.data
	level_label.text  = "Lvl. %d" % d.player_level
	coins_label.text  = "%d 🪙" % d.coins
	xp_bar.max_value  = GameManager.xp_for_next_level()
	xp_bar.value      = d.xp
	xp_bar.tooltip_text = "%d / %d XP" % [d.xp, GameManager.xp_for_next_level()]

# ── Stats Joueur ───────────────────────────────────────────────────────────────	
func _get_player_max_hp() -> int:
	return 100 + GameManager.get_bonus_hp()

# ── Signaux GameManager ────────────────────────────────────────────────────────
func _on_leveled_up(new_level: int) -> void:
	_refresh_stats_bar()
	_show_levelup_overlay(new_level)

func _on_mastery_changed(_kanji_id: int, _new_value: float) -> void:
	_refresh_stats_bar()
	
func _on_dex_pressed() -> void:
	GameManager.go_to("res://scenes/kanji_dex/KanjiDex.tscn")

# ── Overlay Level Up ───────────────────────────────────────────────────────────
func _show_levelup_overlay(new_level: int) -> void:
	var unlocked_count = KanjiDB.get_unlocked(new_level).size() \
						- KanjiDB.get_unlocked(new_level - 1).size()

	levelup_title.text = "LEVEL UP !"
	if unlocked_count > 0:
		levelup_sub.text = "Level %d  —  %d new kanji(s) unlocked !" \
						   % [new_level, unlocked_count]
	else:
		levelup_sub.text = "Level %d" % new_level

	levelup_overlay.visible = true
	await get_tree().create_timer(2.5).timeout
	levelup_overlay.visible = false

# ── Nouveau combat ─────────────────────────────────────────────────────────────
func start_combat() -> void:
	_newly_discovered_this_fight.clear()
	boss      = BossGenerator.generate()
	boss_hp   = boss["max_hp"]
	player_max_hp = _get_player_max_hp()
	player_hp = player_max_hp

	boss_hp_bar.max_value   = boss_hp
	boss_hp_bar.value       = boss_hp
	player_hp_bar.max_value = player_hp
	player_hp_bar.value     = player_hp

	boss_name_label.text = boss["name"]
	info_label.text      = ""
	_update_player_label()
	_refresh_stats_bar()
	_next_question()

# ── Questions ──────────────────────────────────────────────────────────────────
func _next_question() -> void:
	var pool : Array = boss["kanji_pool"]
	if pool.is_empty():
		return

	var kanji         = pool[randi() % pool.size()]
	current_question   = KanjiDB.build_question(kanji)
	awaiting_answer    = true

	boss_sprite.text    = kanji["character"] if current_question["type"] != "character" else "?"
	question_label.text = current_question["prompt"]
	info_label.text     = ""

	var choices = current_question["choices"]
	var buttons := answer_grid.get_children()
	for i in range(buttons.size()):
		buttons[i].text     = choices[i] if i < choices.size() else "—"
		buttons[i].disabled = false
		buttons[i].modulate = Color.WHITE

# ── Réponse ────────────────────────────────────────────────────────────────────
func _on_answer_pressed(idx: int) -> void:
	if not awaiting_answer:
		return
	awaiting_answer = false

	var buttons   := answer_grid.get_children()
	var chosen    : String = current_question["choices"][idx]
	var correct   : String = current_question["correct"]
	var kanji_id  : int    = current_question["kanji_id"]
	var is_correct         := chosen == correct

	for i in range(buttons.size()):
		buttons[i].disabled = true
		if current_question["choices"][i] == correct:
			buttons[i].modulate = Color(0.3, 1.0, 0.4)
		elif i == idx and not is_correct:
			buttons[i].modulate = Color(1.0, 0.3, 0.3)

	GameManager.update_mastery(kanji_id, is_correct)
	if not GameManager.is_discovered(kanji_id):
		_newly_discovered_this_fight.append(kanji_id)
	GameManager.discover_kanji(kanji_id)

	if is_correct:
		var dmg           := _compute_player_damage()
		boss_hp            = max(0, boss_hp - dmg)
		boss_hp_bar.value  = boss_hp
		var mastery_pct   := int(GameManager.get_mastery(kanji_id) * 100)
		_show_info("✓  -%d HP dealt   (Mastery %d%%)" % [dmg, mastery_pct], true)
	else:
		var dmg_taken = max(1, boss["damage"] - GameManager.get_damage_reduction())
		player_hp = max(0, player_hp - dmg_taken)
		player_hp_bar.value = player_hp
		_update_player_label()
		_show_info("✗  False — %s   (-%d HP)" % [correct, dmg_taken], false)

	await get_tree().create_timer(1.5).timeout

	if boss_hp <= 0:
		_on_victory()
	elif player_hp <= 0:
		_on_defeat()
	else:
		_next_question()

func _compute_player_damage() -> int:
	var mastery     = GameManager.get_mastery(current_question["kanji_id"])
	var base_damage := int(15.0 + (1.0 - mastery) * 10.0)
	return base_damage + GameManager.get_bonus_damage()

# ── Consommables ────────────────────────────────────────────────────────
func _try_use_potion() -> void:
	# Cherche heal_full en priorité, sinon heal
	for item_id in [8, 7]:
		if GameManager.has_item(item_id):
			var item = ItemDB.get_by_id(item_id)
			GameManager.use_consumable(item_id)
			if item["effect"]["stat"] == "heal_full":
				player_hp = player_max_hp
			else:
				player_hp = min(player_max_hp, player_hp + item["effect"]["value"])
			player_hp_bar.value = player_hp
			_update_player_label()
			_show_info("🧪 %s utilisé !" % item["name"], true)
			_refresh_stats_bar()
			return
	_show_info("Aucune potion en inventaire (achetez-en à la boutique)", false)

# ── Victoire / Défaite ────────────────────────────────────────────────────────
func _on_victory() -> void:
	GameManager.add_xp(boss["xp_reward"])
	GameManager.add_coins(boss["coin_reward"])
	_refresh_stats_bar()

	# Récupère les kanjis nouvellement découverts pendant CE combat
	var newly_discovered : Array = []
	for kanji in boss["kanji_pool"]:
		if GameManager.is_discovered(kanji["id"]):
			# Découvert lors de ce combat ou avant — on filtre ceux d'avant
			pass
	# On refait proprement : on note les découverts AVANT le combat
	# (voir _on_answer_pressed — on ajoute le tracking ci-dessous)
	for kanji_id in _newly_discovered_this_fight:
		var k = KanjiDB.get_by_id(kanji_id)
		if not k.is_empty():
			newly_discovered.append(k)

	_newly_discovered_this_fight.clear()

	# Instancie et affiche l'écran de victoire
	var vs := VICTORY_SCENE.instantiate()
	$UI.add_child(vs)
	vs.setup(boss, newly_discovered)
	vs.continue_pressed.connect(func():
		vs.queue_free()
		start_combat()
	)

	# Cache les boutons de réponse pendant l'écran
	for btn in answer_grid.get_children():
		btn.disabled = true

func _on_defeat() -> void:
	var penalty = min(GameManager.data.coins, 5)
	if penalty > 0:
		GameManager.spend_coins(penalty)
	_refresh_stats_bar()
	_show_info("✖  Défaite  -%d pièces — nouveau combat…" % penalty, false)
	question_label.text = "Nouveau combat dans 3 secondes…"
	boss_sprite.text    = "✖"
	for btn in answer_grid.get_children():
		btn.text = "" ; btn.disabled = true

	await get_tree().create_timer(3.0).timeout
	start_combat()

# ── Helpers UI ────────────────────────────────────────────────────────────────
func _show_info(msg: String, positive: bool) -> void:
	info_label.text     = msg
	info_label.modulate = Color(0.3, 1.0, 0.4) if positive else Color(1.0, 0.3, 0.3)

func _update_player_label() -> void:
	player_hp_label.text = "PV : %d / %d" % [player_hp, _get_player_max_hp()]
	
# ── TESTING INPUTS (DEV) ────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# T → ajoute 50 XP pour tester le level up
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			GameManager.add_xp(50)
			_refresh_stats_bar()
			print("XP forcé : %d / %d" % [GameManager.data.xp, GameManager.xp_for_next_level()])
		if event.keycode == KEY_C:
			GameManager.add_coins(50)
			_refresh_stats_bar()
			print("Coins forcé : %d" % [GameManager.data.coins])
		# R → reset complet (utile pendant le dev)
		if event.keycode == KEY_R:
			GameManager.reset_save()
			start_combat()
			_refresh_stats_bar()
			print("Sauvegarde réinitialisée")
		if event.keycode == KEY_H:
			_try_use_potion()
