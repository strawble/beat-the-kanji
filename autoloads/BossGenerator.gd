extends Node

const BOSS_NAMES := [
	"Oni Kanji", "Word Shogun", "Syllabic Demon",
	"Ideographic Specter", "Hanzi Lord", "Radical Ghost"
]
const BOSS_KANJI_COUNT := 3

func generate() -> Dictionary:
	var level_def : Dictionary = GameManager.current_level
	var kanji_pool : Array     = _get_kanji_pool(level_def)
	var player_level : int     = GameManager.data.player_level
	var difficulty : float     = _compute_difficulty(kanji_pool)
	return {
		"name":        BOSS_NAMES[randi() % BOSS_NAMES.size()],
		"max_hp":      _compute_hp(player_level, difficulty),
		"damage":      _compute_damage(player_level, difficulty),
		"xp_reward":   _compute_xp(player_level),
		"coin_reward": _compute_coins(player_level),
		"kanji_pool":  kanji_pool,
	}

func _get_kanji_pool(level_def: Dictionary) -> Array:
	# Use the kanjis defined by the level
	var ids : Array = level_def.get("kanji_ids", [])
	var pool : Array = []
	for id in ids:
		var k : Dictionary = KanjiDB.get_by_id(id)
		if not k.is_empty():
			pool.append(k)
	# Safety: if the level has no kanjis defined, fall back to unlocked ones
	if pool.is_empty():
		pool = KanjiDB.get_unlocked(GameManager.data.player_level)
		pool.shuffle()
		pool = pool.slice(0, BOSS_KANJI_COUNT)
	return pool

func _compute_difficulty(pool: Array) -> float:
	if pool.is_empty(): return 0.5
	var total : float = 0.0
	for k in pool:
		total += GameManager.get_mastery(k["id"])
	var avg_mastery : float = total / pool.size()
	return clamp(1.0 - avg_mastery, 0.1, 1.0)

func _compute_hp(level: int, difficulty: float) -> int:
	return int((60.0 + level * 25.0) * (0.75 + difficulty * 0.5))

func _compute_damage(level: int, difficulty: float) -> int:
	return max(1, int((3.0 + level * 1.5) * difficulty))

func _compute_xp(level: int) -> int:
	return 20 + level * 10

func _compute_coins(level: int) -> int:
	return 5 + level * 3
