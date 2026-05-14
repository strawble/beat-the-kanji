class_name PlayerData
extends Resource

@export var player_level : int = 1
@export var xp           : int = 0
@export var coins        : int = 0

@export var kanji_mastery        : Dictionary = {}
@export var discovered_kanji_ids : Array[int] = []

# Inventaire : ids des items possédés
@export var inventory : Array[int] = []

# Slots d'équipement : -1 = rien d'équipé
@export var equipped_weapon    : int = -1
@export var equipped_armor     : int = -1
@export var equipped_accessory : int = -1

# Zones
@export var active_zone_id    : int        = 1
@export var unlocked_zone_ids : Array[int] = [1]

# Améliorations de stats permanentes (clé = nom de stat, valeur = niveau)
# Stats : strength, max_hp, crit_rate, crit_dmg, dodge_chance, hp_regen
@export var stat_upgrades : Dictionary = {}

# Bouclier de résurrection actif
@export var has_revive_shield : bool = false
