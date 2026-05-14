extends Node2D

const ITEM_ROW_SCENE         := preload("res://scenes/shop/ItemRow.tscn")
const STAT_UPGRADE_ROW_SCENE := preload("res://scenes/shop/StatUpgradeRow.tscn")

# ── Références (existantes) ───────────────────────────────────────────────────
@onready var coins_label    : Label         = $UI/Root/VBox/CoinsLabel
@onready var item_grid      : VBoxContainer = $UI/Root/VBox/ItemList/ItemGrid
@onready var equipped_details : Label       = $UI/Root/VBox/EquippedPanel/EquippedVBox/EquippedDetails

# ── Onglets ───────────────────────────────────────────────────────────────────
@onready var tab_weapon     : Button = $UI/Root/VBox/TabBar/TabWeapon
@onready var tab_armor      : Button = $UI/Root/VBox/TabBar/TabArmor
@onready var tab_accessory  : Button = get_node_or_null("UI/Root/VBox/TabBar/TabAccessory")
@onready var tab_consumable : Button = $UI/Root/VBox/TabBar/TabConsumable
@onready var tab_upgrade    : Button = get_node_or_null("UI/Root/VBox/TabBar/TabUpgrade")

@onready var sets_label : Label = get_node_or_null("UI/Root/VBox/SetsLabel")

var _current_tab : String = "weapon"

# Liste des stats améliorables
const UPGRADE_STATS := ["strength", "max_hp", "crit_rate", "crit_dmg", "dodge_chance", "hp_regen"]

func _ready() -> void:
	# NavBar globale
	NavBar.show_for_scene("shop")

	# Creation of the "Accessoires" et "Améliorations" si la scène n'a pas été
	# mise à jour manuellement (rétrocompatible).
	_ensure_tabs_exist()

	tab_weapon.pressed.connect(func():     _switch_tab("weapon"))
	tab_armor.pressed.connect(func():      _switch_tab("armor"))
	if tab_accessory:
		tab_accessory.pressed.connect(func(): _switch_tab("accessory"))
	tab_consumable.pressed.connect(func(): _switch_tab("consumable"))
	if tab_upgrade:
		tab_upgrade.pressed.connect(func(): _switch_tab("upgrade"))

	_refresh_coins()
	_refresh_equipped()
	_refresh_sets_label()
	_switch_tab("weapon")

func _ensure_tabs_exist() -> void:
	var tabbar := $UI/Root/VBox/TabBar
	if tab_accessory == null:
		tab_accessory = Button.new()
		tab_accessory.name = "TabAccessory"
		tab_accessory.text = "💍 Accessories"
		tab_accessory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_accessory.custom_minimum_size = Vector2(0, 38)
		tabbar.add_child(tab_accessory)
		# Place après TabArmor
		tabbar.move_child(tab_accessory, tab_armor.get_index() + 1)
	if tab_upgrade == null:
		tab_upgrade = Button.new()
		tab_upgrade.name = "TabUpgrade"
		tab_upgrade.text = "⬆ Upgrades"
		tab_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_upgrade.custom_minimum_size = Vector2(0, 38)
		tabbar.add_child(tab_upgrade)

	# SetsLabel pour afficher les bonus de sets équipés
	if sets_label == null:
		var vbox := $UI/Root/VBox
		sets_label = Label.new()
		sets_label.name = "SetsLabel"
		sets_label.add_theme_font_size_override("font_size", 12)
		sets_label.modulate = Color(0.8, 0.7, 1.0)
		vbox.add_child(sets_label)
		# Le placer juste avant EquippedPanel
		var ep := $UI/Root/VBox/EquippedPanel
		vbox.move_child(sets_label, ep.get_index())

func _switch_tab(type: String) -> void:
	_current_tab = type
	if type == "upgrade":
		_populate_upgrades()
	else:
		_populate_items(type)
	_highlight_tabs()

func _highlight_tabs() -> void:
	var tabs : Dictionary = {
		"weapon":     tab_weapon,
		"armor":      tab_armor,
		"accessory":  tab_accessory,
		"consumable": tab_consumable,
		"upgrade":    tab_upgrade
	}
	for key in tabs:
		var btn : Button = tabs[key]
		if btn == null: continue
		btn.modulate = Color.WHITE if key == _current_tab else Color(0.7, 0.7, 0.7)

# ── Onglets items ─────────────────────────────────────────────────────────────
func _populate_items(type: String) -> void:
	for child in item_grid.get_children():
		child.queue_free()
	var items := ItemDB.get_by_type(type)
	for item in items:
		var row := ITEM_ROW_SCENE.instantiate()
		item_grid.add_child(row)
		row.call_deferred("setup", item)
		row.action_requested.connect(_on_item_action)

func _on_item_action(item: Dictionary) -> void:
	var type : String = item["type"]
	var owned := GameManager.has_item(item["id"])

	if type == "consumable":
		if GameManager.buy_item(item["id"]):
			_feedback("Bought: %s" % item["name"])
	elif owned:
		GameManager.equip_item(item["id"])
		_feedback("Equipped: %s" % item["name"])
	else:
		if GameManager.buy_item(item["id"]):
			GameManager.equip_item(item["id"])
			_feedback("Bought and equipped: %s" % item["name"])
		else:
			_feedback("Not enough coins !")
	_refresh_coins()
	_refresh_equipped()
	_refresh_sets_label()
	_populate_items(_current_tab)

# ── Upgrades tab ──────────────────────────────────────────────────────
func _populate_upgrades() -> void:
	for child in item_grid.get_children():
		child.queue_free()
	for stat in UPGRADE_STATS:
		var row := STAT_UPGRADE_ROW_SCENE.instantiate()
		item_grid.add_child(row)
		row.call_deferred("setup", stat)
		row.upgrade_requested.connect(_on_upgrade_requested)

func _on_upgrade_requested(stat: String) -> void:
	if GameManager.buy_upgrade(stat):
		_feedback("%s upgraded !" % StatUpgradeRow.STAT_INFO[stat]["name"])
	else:
		_feedback("Not enough coins !")
	_refresh_coins()
	_populate_upgrades()

# ── Affichages ────────────────────────────────────────────────────────────────
func _refresh_coins() -> void:
	coins_label.text = "%d 🪙" % GameManager.data.coins

func _refresh_equipped() -> void:
	var wpn_id := GameManager.data.equipped_weapon
	var arm_id := GameManager.data.equipped_armor
	var acc_id := GameManager.data.equipped_accessory
	var wpn_name := "none"
	var arm_name := "none"
	var acc_name := "none"
	if wpn_id != -1:
		var w := ItemDB.get_by_id(wpn_id)
		if not w.is_empty(): wpn_name = w["name"]
	if arm_id != -1:
		var a := ItemDB.get_by_id(arm_id)
		if not a.is_empty(): arm_name = a["name"]
	if acc_id != -1:
		var ac := ItemDB.get_by_id(acc_id)
		if not ac.is_empty(): acc_name = ac["name"]
	equipped_details.text = "⚔ %s    🛡 %s    💍 %s" % [wpn_name, arm_name, acc_name]

func _refresh_sets_label() -> void:
	if sets_label == null: return
	var lines : Array[String] = []
	for s in ItemDB.get_sets():
		var tag : String = s["tag"]
		var pieces := GameManager.count_set_pieces(tag)
		var required : int = s["pieces_required"]
		var icon := "✓" if pieces >= required else "○"
		lines.append("%s %s (%d/%d) — %s" % [icon, s["name"], pieces, required, s["bonus_description"]])
	sets_label.text = "\n".join(lines)

func _feedback(msg: String) -> void:
	coins_label.text = msg
	await get_tree().create_timer(1.2).timeout
	_refresh_coins()
