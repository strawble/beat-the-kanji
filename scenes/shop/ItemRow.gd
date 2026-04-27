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
	desc_label.text = item["description"]
	cost_label.text = "%d 🪙" % item["cost"]
	action_btn.pressed.connect(func(): emit_signal("action_requested", _item))
	_refresh_button()

func _refresh_button() -> void:
	var owned   := GameManager.has_item(_item["id"])
	var type    = _item["type"]
	var eq_wpn  := GameManager.data.equipped_weapon
	var eq_arm  := GameManager.data.equipped_armor

	match type:
		"weapon":
			if _item["id"] == eq_wpn:
				action_btn.text     = "✓ Équipé"
				action_btn.disabled = true
			elif owned:
				action_btn.text     = "Équiper"
				action_btn.disabled = false
			else:
				action_btn.text     = "Acheter"
				action_btn.disabled = GameManager.data.coins < _item["cost"]
		"armor":
			if _item["id"] == eq_arm:
				action_btn.text     = "✓ Équipé"
				action_btn.disabled = true
			elif owned:
				action_btn.text     = "Équiper"
				action_btn.disabled = false
			else:
				action_btn.text     = "Acheter"
				action_btn.disabled = GameManager.data.coins < _item["cost"]
		"consumable":
			action_btn.text     = "Acheter"
			action_btn.disabled = GameManager.data.coins < _item["cost"]
