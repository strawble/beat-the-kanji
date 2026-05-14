extends PanelContainer
class_name StatUpgradeRow

# A row in the shop's Upgrades tab.
# Affiche une stat, son niveau actuel, son coût d'amélioration, un bouton "+".

const STAT_INFO := {
	"strength":     { "name": "Strength",            "icon": "⚔",  "desc": "+3 damage per level" },
	"max_hp":       { "name": "Vitality",         "icon": "❤",  "desc": "+10 max HP per level" },
	"crit_rate":    { "name": "Crit Rate",    "icon": "💥", "desc": "+2% crit chance per level" },
	"crit_dmg":     { "name": "Crit Damage",      "icon": "🔥", "desc": "+10% crit damage per level" },
	"dodge_chance": { "name": "Dodge",          "icon": "💨", "desc": "+1.5% dodge per level" },
	"hp_regen":     { "name": "Regeneration",     "icon": "✚",  "desc": "+2 HP/answer per level" }
}

signal upgrade_requested(stat: String)

var _stat_key : String = ""

@onready var icon_label : Label  = $HBox/IconLabel
@onready var name_label : Label  = $HBox/InfoVBox/NameLabel
@onready var desc_label : Label  = $HBox/InfoVBox/DescLabel
@onready var level_label: Label  = $HBox/LevelLabel
@onready var cost_label : Label  = $HBox/CostLabel
@onready var buy_btn    : Button = $HBox/BuyBtn

func setup(stat_key: String) -> void:
	_stat_key = stat_key
	var info  : Dictionary = STAT_INFO.get(stat_key, { "name": stat_key, "icon": "?", "desc": "" })
	icon_label.text = info["icon"]
	name_label.text = info["name"]
	desc_label.text = info["desc"]
	for c in buy_btn.pressed.get_connections():
		buy_btn.pressed.disconnect(c.callable)
	buy_btn.pressed.connect(func(): emit_signal("upgrade_requested", _stat_key))
	refresh()

func refresh() -> void:
	var lvl := GameManager.get_upgrade_level(_stat_key)
	var cost := GameManager.get_upgrade_cost(_stat_key)
	level_label.text = "Lv. %d / %d" % [lvl, GameManager.UPGRADE_MAX_LEVEL]
	if cost < 0:
		cost_label.text = "MAX"
		buy_btn.text = "—"
		buy_btn.disabled = true
	else:
		cost_label.text = "%d 🪙" % cost
		buy_btn.text = "Buy"
		buy_btn.disabled = GameManager.data.coins < cost
