extends Node

const SAVE_PATH   := "user://save.tres"
const XP_PER_LEVEL := 100   # XP de base pour passer au niveau suivant

var data: PlayerData

# Niveau en cours (défini par MainMenu avant de lancer GameWorld)
var current_level : Dictionary = {
	"id": 1,
	"title": "Niveau 1",
	"subtitle": "Soleil · Lune · Feu",
	"kanji_ids": [1, 2, 3],
	"unlocked": true,
}

signal leveled_up(new_level: int)
signal mastery_changed(kanji_id: int, new_value: float)

func _ready() -> void:
	load_game()

# ── Save / Load ────────────────────────────────────────────────────────────────

func load_game() -> void:
	if ResourceLoader.exists(SAVE_PATH):
		data = load(SAVE_PATH) as PlayerData
	if data == null:
		data = PlayerData.new()
		print("GameManager: nouvelle partie.")
	else:
		print("GameManager: sauvegarde chargée — niveau %d" % data.player_level)

func save_game() -> void:
	ResourceSaver.save(data, SAVE_PATH)

func reset_save() -> void:    # Utile pendant le dev
	data = PlayerData.new()
	save_game()

# ── XP & Niveaux ───────────────────────────────────────────────────────────────

func add_xp(amount: int) -> void:
	data.xp += amount
	_check_level_up()
	save_game()

func _check_level_up() -> void:
	var needed := xp_for_next_level()
	while data.xp >= needed:
		data.xp -= needed
		data.player_level += 1
		needed = xp_for_next_level()
		emit_signal("leveled_up", data.player_level)
		print("LEVEL UP → niveau %d" % data.player_level)

func xp_for_next_level() -> int:
	# Courbe légèrement progressive : 100, 120, 140, ...
	return XP_PER_LEVEL + (data.player_level - 1) * 20

# ── Pièces ─────────────────────────────────────────────────────────────────────

func add_coins(amount: int) -> void:
	data.coins += amount
	save_game()

func spend_coins(amount: int) -> bool:
	if data.coins < amount:
		return false
	data.coins -= amount
	save_game()
	return true

# ── Maîtrise des kanjis ────────────────────────────────────────────────────────

func get_mastery(kanji_id: int) -> float:
	return data.kanji_mastery.get(kanji_id, 0.0)

func update_mastery(kanji_id: int, correct: bool) -> void:
	var m := get_mastery(kanji_id)
	m = clamp(m + (0.15 if correct else -0.10), 0.0, 1.0)
	data.kanji_mastery[kanji_id] = m
	emit_signal("mastery_changed", kanji_id, m)
	save_game()

# ── Découverte ─────────────────────────────────────────────────────────────────

func discover_kanji(kanji_id: int) -> void:
	if kanji_id not in data.discovered_kanji_ids:
		data.discovered_kanji_ids.append(kanji_id)
		save_game()

func is_discovered(kanji_id: int) -> bool:
	return kanji_id in data.discovered_kanji_ids

# ── Navigation ─────────────────────────────────────────────────────────────────

func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func set_current_level(level: Dictionary) -> void:
	current_level = level
	
# ── Inventaire & Équipement ────────────────────────────────────────────────────

func buy_item(item_id: int) -> bool:
	var item := ItemDB.get_by_id(item_id)
	if item.is_empty():
		return false
	if not spend_coins(item["cost"]):
		return false
	data.inventory.append(item_id)
	save_game()
	return true

func equip_item(item_id: int) -> void:
	var item := ItemDB.get_by_id(item_id)
	if item.is_empty() or item["type"] == "consumable":
		return
	if item["type"] == "weapon":
		data.equipped_weapon = item_id
	elif item["type"] == "armor":
		data.equipped_armor = item_id
	save_game()

func use_consumable(item_id: int) -> bool:
	if item_id not in data.inventory:
		return false
	data.inventory.erase(item_id)
	save_game()
	return true

func has_item(item_id: int) -> bool:
	return item_id in data.inventory

# ── Stats effectives (base + équipement) ──────────────────────────────────────

func get_bonus_damage() -> int:
	if data.equipped_weapon == -1:
		return 0
	var w := ItemDB.get_by_id(data.equipped_weapon)
	if w.is_empty() or w["effect"]["stat"] != "bonus_damage":
		return 0
	return w["effect"]["value"]

func get_bonus_hp() -> int:
	if data.equipped_armor == -1:
		return 0
	var a := ItemDB.get_by_id(data.equipped_armor)
	if a.is_empty() or a["effect"]["stat"] != "bonus_hp":
		return 0
	return a["effect"]["value"]

func get_damage_reduction() -> int:
	if data.equipped_armor == -1:
		return 0
	var a := ItemDB.get_by_id(data.equipped_armor)
	if a.is_empty() or a["effect"]["stat"] != "damage_reduction":
		return 0
	return a["effect"]["value"]
