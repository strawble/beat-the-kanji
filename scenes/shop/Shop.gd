extends Node2D

const ITEM_ROW_SCENE := preload("res://scenes/shop/ItemRow.tscn")

@onready var coins_label    : Label        = $UI/Root/VBox/CoinsLabel
@onready var tab_weapon     : Button       = $UI/Root/VBox/TabBar/TabWeapon
@onready var tab_armor      : Button       = $UI/Root/VBox/TabBar/TabArmor
@onready var tab_consumable : Button       = $UI/Root/VBox/TabBar/TabConsumable
@onready var item_grid      : VBoxContainer = $UI/Root/VBox/ItemList/ItemGrid
@onready var back_button    : Button       = $UI/Root/VBox/TitleBar/BackButton
@onready var equipped_details : Label      = $UI/Root/VBox/EquippedPanel/EquippedVBox/EquippedDetails

var _current_tab : String = "weapon"

func _ready() -> void:
	back_button.pressed.connect(func(): GameManager.go_to("res://scenes/game_world/GameWorld.tscn"))
	tab_weapon.pressed.connect(func():     _switch_tab("weapon"))
	tab_armor.pressed.connect(func():      _switch_tab("armor"))
	tab_consumable.pressed.connect(func(): _switch_tab("consumable"))
	_refresh_coins()
	_refresh_equipped()
	_switch_tab("weapon")

func _switch_tab(type: String) -> void:
	_current_tab = type
	_populate(type)
	# Feedback visuel sur l'onglet actif
	tab_weapon.modulate     = Color.WHITE if type == "weapon"     else Color(0.7, 0.7, 0.7)
	tab_armor.modulate      = Color.WHITE if type == "armor"      else Color(0.7, 0.7, 0.7)
	tab_consumable.modulate = Color.WHITE if type == "consumable" else Color(0.7, 0.7, 0.7)

func _populate(type: String) -> void:
	for child in item_grid.get_children():
		child.queue_free()

	var items := ItemDB.get_by_type(type)
	for item in items:
		var row := ITEM_ROW_SCENE.instantiate()
		item_grid.add_child(row)
		row.call_deferred("setup", item)
		row.action_requested.connect(_on_action)

func _on_action(item: Dictionary) -> void:
	var type = item["type"]
	var owned := GameManager.has_item(item["id"])

	if type == "consumable":
		if GameManager.buy_item(item["id"]):
			_feedback("Acheté : %s" % item["name"])
	elif owned:
		GameManager.equip_item(item["id"])
		_feedback("Équipé : %s" % item["name"])
	else:
		if GameManager.buy_item(item["id"]):
			GameManager.equip_item(item["id"])
			_feedback("Acheté et équipé : %s" % item["name"])
		else:
			_feedback("Pas assez de pièces !")

	_refresh_coins()
	_refresh_equipped()
	_populate(_current_tab)

func _refresh_coins() -> void:
	coins_label.text = "%d 🪙" % GameManager.data.coins

func _refresh_equipped() -> void:
	var wpn_id := GameManager.data.equipped_weapon
	var arm_id := GameManager.data.equipped_armor
	var wpn_name := "aucune"
	var arm_name := "aucune"
	if wpn_id != -1:
		var w := ItemDB.get_by_id(wpn_id)
		if not w.is_empty(): wpn_name = w["name"]
	if arm_id != -1:
		var a := ItemDB.get_by_id(arm_id)
		if not a.is_empty(): arm_name = a["name"]
	equipped_details.text = "⚔ %s     🛡 %s" % [wpn_name, arm_name]

func _feedback(msg: String) -> void:
	# Réutilise le CoinsLabel brièvement pour le feedback
	coins_label.text = msg
	await get_tree().create_timer(1.2).timeout
	_refresh_coins()
