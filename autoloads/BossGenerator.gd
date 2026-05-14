extends Node

const BOSS_NAMES := [
	"Oni Kanji", "Shogun of Words", "Syllabic Demon",
	"Ideographic Spectre", "Hanzi Lord", "Radical Phantom",
	"Pictographic Spirit", "Master of Radicals", "Shadow of Ink"
]

func generate() -> Dictionary:
	var level    := GameManager.data.player_level
	var zone_id  := GameManager.data.active_zone_id
	var unlocked := KanjiDB.get_unlocked_in_zone(level, zone_id)

	# Fallback: empty zone → all unlocked kanjis
	if unlocked.is_empty():
		unlocked = KanjiDB.get_unlocked(level)

	if unlocked.is_empty():
		push_error("BossGenerator: no kanji available")
		return {}

	var kanji_pool := _pick_kanji_pool(unlocked)
	var difficulty := _compute_difficulty(kanji_pool)

	return {
		"name":        BOSS_NAMES[randi() % BOSS_NAMES.size()],
		"max_hp":      _compute_hp(level, difficulty),
		"damage":      _compute_damage(level, difficulty),
		"xp_reward":   _compute_xp(level),
		"coin_reward": _compute_coins(level),
		"kanji_pool":  kanji_pool,
		"zone_id":     zone_id,
	}

func _pick_kanji_pool(unlocked: Array) -> Array:
	var weighted: Array = []
	for k in unlocked:
		var mastery := GameManager.get_mastery(k["id"])
		var weight  := int((1.0 - mastery) * 10) + 1
		for _i in range(weight):
			weighted.append(k)

	weighted.shuffle()

	var seen : Dictionary = {}
	var pool : Array = []
	for k in weighted:
		if k["id"] not in seen:
			seen[k["id"]] = true
			pool.append(k)
		if pool.size() >= 5:
			break

	if pool.size() < min(2, unlocked.size()):
		pool = unlocked.duplicate()
		pool.shuffle()
		pool = pool.slice(0, 2)

	return pool

func _compute_difficulty(pool: Array) -> float:
	if pool.is_empty(): return 0.5
	var total := 0.0
	for k in pool:
		total += GameManager.get_mastery(k["id"])
	return clamp(1.0 - total / pool.size(), 0.1, 1.0)

func _compute_hp(level: int, difficulty: float) -> int:
	return int((60.0 + level * 25.0) * (0.75 + difficulty * 0.5))

func _compute_damage(level: int, difficulty: float) -> int:
	return max(1, int((3.0 + level * 1.5) * difficulty))

func _compute_xp(level: int) -> int:
	return 20 + level * 10

func _compute_coins(level: int) -> int:
	return 5 + level * 3
