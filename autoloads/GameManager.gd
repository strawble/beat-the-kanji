extends Node

const SAVE_PATH    := "user://save.tres"
const XP_PER_LEVEL := 100

var data: PlayerData

# Buffs temporaires (combat en cours uniquement)
var temp_damage_bonus : int = 0
var temp_timer_bonus  : float = 0.0
var temp_timer_uses   : int = 0

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
		print("GameManager: new game.")
	else:
		print("GameManager: save loaded — level %d" % data.player_level)

func save_game() -> void:
	ResourceSaver.save(data, SAVE_PATH)

func reset_save() -> void:
	data = PlayerData.new()
	save_game()

func clear_temp_buffs() -> void:
	temp_damage_bonus = 0
	temp_timer_bonus = 0.0
	temp_timer_uses = 0

# ── XP & Levels ───────────────────────────────────────────────────────────────

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
		print("LEVEL UP → level %d" % data.player_level)

func xp_for_next_level() -> int:
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

func boost_mastery(kanji_id: int, amount: float) -> void:
	var m := get_mastery(kanji_id)
	data.kanji_mastery[kanji_id] = clamp(m + amount, 0.0, 1.0)
	emit_signal("mastery_changed", kanji_id, data.kanji_mastery[kanji_id])
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

# ── Inventory & Equipment ────────────────────────────────────────────────────

func buy_item(item_id: int) -> bool:
	var item := ItemDB.get_by_id(item_id)
	if item.is_empty():
		return false
	if not spend_coins(item["cost"]):
		return false
	data.inventory.append(item_id)
	# Effets immédiats
	for eff in item.get("effects", []):
		if eff["stat"] == "revive":
			data.has_revive_shield = true
	save_game()
	return true

func equip_item(item_id: int) -> void:
	var item := ItemDB.get_by_id(item_id)
	if item.is_empty() or item["type"] == "consumable":
		return
	match item["type"]:
		"weapon":    data.equipped_weapon    = item_id
		"armor":     data.equipped_armor     = item_id
		"accessory": data.equipped_accessory = item_id
	save_game()

func use_consumable(item_id: int) -> bool:
	if item_id not in data.inventory:
		return false
	data.inventory.erase(item_id)
	save_game()
	return true

func has_item(item_id: int) -> bool:
	return item_id in data.inventory

func count_set_pieces(set_tag: String) -> int:
	if set_tag.is_empty():
		return 0
	var count := 0
	for slot_id in [data.equipped_weapon, data.equipped_armor, data.equipped_accessory]:
		if slot_id == -1:
			continue
		var it := ItemDB.get_by_id(slot_id)
		if not it.is_empty() and it.get("set_tag", "") == set_tag:
			count += 1
	return count

# ── Stat upgrades (boutique onglet Améliorations) ──────────────────────────────

const UPGRADE_MAX_LEVEL := 10
const UPGRADE_BASE_COST := {
	"strength":     30,
	"max_hp":       25,
	"crit_rate":    40,
	"crit_dmg":     35,
	"dodge_chance": 50,
	"hp_regen":     30
}

func get_upgrade_level(stat: String) -> int:
	return data.stat_upgrades.get(stat, 0)

func get_upgrade_cost(stat: String) -> int:
	var lvl := get_upgrade_level(stat)
	if lvl >= UPGRADE_MAX_LEVEL:
		return -1
	var base : int = UPGRADE_BASE_COST.get(stat, 50)
	return int(base * pow(1.6, lvl))

func buy_upgrade(stat: String) -> bool:
	var cost := get_upgrade_cost(stat)
	if cost < 0:
		return false
	if not spend_coins(cost):
		return false
	data.stat_upgrades[stat] = get_upgrade_level(stat) + 1
	save_game()
	return true

# ── Calcul des stats effectives ────────────────────────────────────────────────

func get_stat(stat_name: String) -> float:
	var total := _stat_from_upgrades(stat_name)
	total    += _stat_from_equipment(stat_name)
	total    += _stat_from_sets(stat_name)
	return total

func _stat_from_upgrades(stat_name: String) -> float:
	var lvl := get_upgrade_level(stat_name)
	match stat_name:
		"strength":     return lvl * 3.0
		"bonus_damage": return lvl * 3.0   # alias pour compat
		"max_hp":       return lvl * 10.0
		"bonus_hp":     return lvl * 10.0  # alias
		"crit_rate":    return lvl * 2.0
		"crit_dmg":     return lvl * 10.0
		"dodge_chance": return lvl * 1.5
		"hp_regen":     return lvl * 2.0
	return 0.0

func _stat_from_equipment(stat_name: String) -> float:
	var total := 0.0
	for slot_id in [data.equipped_weapon, data.equipped_armor, data.equipped_accessory]:
		if slot_id == -1:
			continue
		var item := ItemDB.get_by_id(slot_id)
		if item.is_empty():
			continue
		for eff in item.get("effects", []):
			if eff.get("stat", "") == stat_name:
				total += float(eff.get("value", 0))
	return total

func _stat_from_sets(stat_name: String) -> float:
	var total := 0.0
	for s in ItemDB.get_sets():
		var tag : String = s.get("tag", "")
		if tag.is_empty():
			continue
		if count_set_pieces(tag) >= s.get("pieces_required", 999):
			for eff in s.get("bonus_effects", []):
				if eff.get("stat", "") == stat_name:
					total += float(eff.get("value", 0))
	return total

# ── Raccourcis stats ──────────────────────────────────────────────────────────

func get_bonus_damage() -> int:
	# strength sert d'alias pour bonus_damage
	return int(get_stat("bonus_damage") + get_stat("strength")) + temp_damage_bonus

func get_bonus_hp() -> int:
	return int(get_stat("bonus_hp") + get_stat("max_hp"))

func get_damage_reduction() -> int:
	return int(get_stat("damage_reduction"))

func get_crit_rate() -> float:
	return clamp(get_stat("crit_rate"), 0.0, 75.0)

func get_crit_dmg_multiplier() -> float:
	return 1.5 + get_stat("crit_dmg") / 100.0

func get_dodge_chance() -> float:
	return clamp(get_stat("dodge_chance"), 0.0, 60.0)

func get_hp_regen() -> int:
	return int(get_stat("hp_regen"))
