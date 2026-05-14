extends PanelContainer

@onready var name_label : Label  = $HBox/InfoVBox/NameLabel
@onready var desc_label : Label  = $HBox/InfoVBox/DescLabel
@onready var cost_label : Label  = $HBox/CostLabel
@onready var action_btn : Button = $HBox/ActionBtn

var _item : Dictionary = {}

signal action_requested(item: Dictionary)

func setup(item: Dictionary) -> void:
	_item = item
	name_label.text = item["name"]
	# Couleur du nom selon le tier
	name_label.add_theme_color_override("font_color", ItemDB.tier_color(item.get("tier", "common")))
	desc_label.text = item["description"]
	# Affiche le tag de set s'il y en a un
	var set_tag : String = item.get("set_tag", "")
	if not set_tag.is_empty():
		var set_data := ItemDB.get_set_by_tag(set_tag)
		if not set_data.is_empty():
			desc_label.text += "  ⚪ Set: %s" % set_data["name"]
	cost_label.text = "%d 🪙" % item["cost"]

	# Reset puis reconnecte (au cas où le row est recyclé)
	for c in action_btn.pressed.get_connections():
		action_btn.pressed.disconnect(c.callable)
	action_btn.pressed.connect(func(): emit_signal("action_requested", _item))
	_refresh_button()

func _refresh_button() -> void:
	var owned   := GameManager.has_item(_item["id"])
	var type    : String = _item["type"]
	var eq_wpn  := GameManager.data.equipped_weapon
	var eq_arm  := GameManager.data.equipped_armor
	var eq_acc  := GameManager.data.equipped_accessory
	var equipped_id := -1
	match type:
		"weapon":    equipped_id = eq_wpn
		"armor":     equipped_id = eq_arm
		"accessory": equipped_id = eq_acc

	match type:
		"weapon", "armor", "accessory":
			if _item["id"] == equipped_id:
				action_btn.text     = "✓ Equipped"
				action_btn.disabled = true
			elif owned:
				action_btn.text     = "Equip"
				action_btn.disabled = false
			else:
				action_btn.text     = "Buy"
				action_btn.disabled = GameManager.data.coins < _item["cost"]
		"consumable":
			action_btn.text     = "Buy"
			action_btn.disabled = GameManager.data.coins < _item["cost"]
