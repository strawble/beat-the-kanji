class_name PlayerData
extends Resource

@export var player_level : int = 1
@export var xp           : int = 0
@export var coins        : int = 0

@export var kanji_mastery        : Dictionary  = {}
@export var discovered_kanji_ids : Array[int]  = []

# Ids des items possédés (peut en avoir plusieurs du même pour les consommables)
@export var inventory : Array[int] = []

# Slot d'équipement : -1 = rien d'équipé
@export var equipped_weapon : int = -1
@export var equipped_armor  : int = -1
