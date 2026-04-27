extends Node

# Noms de boss générés aléatoirement (à enrichir plus tard)
const BOSS_NAMES := [
	"Oni Kanji", "Shogun des Mots", "Démon Syllabique",
	"Spectre Idéographique", "Seigneur Hanzi", "Fantôme Radicalaire"
]

func generate() -> Dictionary:
	var level       := GameManager.data.player_level
	var unlocked    := KanjiDB.get_unlocked(level)

	if unlocked.is_empty():
		push_error("BossGenerator: aucun kanji disponible")
		return {}

	var kanji_pool  := _pick_kanji_pool(unlocked)
	var difficulty  := _compute_difficulty(kanji_pool)

	return {
		"name":        BOSS_NAMES[randi() % BOSS_NAMES.size()],
		"max_hp":      _compute_hp(level, difficulty),
		"damage":      _compute_damage(level, difficulty),
		"xp_reward":   _compute_xp(level),
		"coin_reward": _compute_coins(level),
		"kanji_pool":  kanji_pool,   # Array de dicts kanji
	}

# ── Sélection du pool de kanjis ────────────────────────────────────────────────

func _pick_kanji_pool(unlocked: Array) -> Array:
	# Pondération inverse de la maîtrise : kanji peu maîtrisé = plus probable
	var weighted: Array = []
	for k in unlocked:
		var mastery := GameManager.get_mastery(k["id"])
		var weight  := int((1.0 - mastery) * 10) + 1   # 1..11
		for _i in range(weight):
			weighted.append(k)

	weighted.shuffle()

	# Dédoublonne en conservant l'ordre shufflé
	var seen: Dictionary = {}
	var pool: Array = []
	for k in weighted:
		if k["id"] not in seen:
			seen[k["id"]] = true
			pool.append(k)
		if pool.size() >= 5:
			break

	# Garantit au minimum 2 kanjis même si le pool est très petit
	if pool.size() < min(2, unlocked.size()):
		pool = unlocked.duplicate()
		pool.shuffle()
		pool = pool.slice(0, 2)

	return pool

# ── Formules de scaling ────────────────────────────────────────────────────────

func _compute_difficulty(pool: Array) -> float:
	if pool.is_empty(): return 0.5
	var total := 0.0
	for k in pool:
		total += GameManager.get_mastery(k["id"])
	var avg_mastery := total / pool.size()
	return clamp(1.0 - avg_mastery, 0.1, 1.0)

func _compute_hp(level: int, difficulty: float) -> int:
	return int((60.0 + level * 25.0) * (0.75 + difficulty * 0.5))

func _compute_damage(level: int, difficulty: float) -> int:
	return max(1, int((3.0 + level * 1.5) * difficulty))

func _compute_xp(level: int) -> int:
	return 20 + level * 10

func _compute_coins(level: int) -> int:
	return 5 + level * 3
