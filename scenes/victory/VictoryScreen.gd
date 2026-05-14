extends Node2D

const CARD_SCENE := preload("res://scenes/kanji_dex/KanjiCard.tscn")

@onready var title_label   : Label         = $UI/Overlay/CenterBox/Panel/VBox/TitleLabel
@onready var rewards_label : Label         = $UI/Overlay/CenterBox/Panel/VBox/RewardsLabel
@onready var new_label     : Label         = $UI/Overlay/CenterBox/Panel/VBox/NewLabel
@onready var cards_row     : HBoxContainer = $UI/Overlay/CenterBox/Panel/VBox/CardsRow
@onready var continue_btn  : Button        = $UI/Overlay/CenterBox/Panel/VBox/ContinueBtn

signal continue_pressed

func _ready() -> void:
	continue_btn.pressed.connect(_on_continue)

func setup(boss: Dictionary, newly_discovered: Array) -> void:
	rewards_label.text = "+%d XP     +%d 🪙" % [boss["xp_reward"], boss["coin_reward"]]
	for c in cards_row.get_children():
		c.queue_free()
	if newly_discovered.is_empty():
		new_label.text = "No new kanji — onward!"
	else:
		new_label.text = "%d new kanji(s):" % newly_discovered.size()
		for kanji in newly_discovered:
			var card := CARD_SCENE.instantiate() as PanelContainer
			cards_row.add_child(card)
			card.call_deferred("setup", kanji, true)

func _on_continue() -> void:
	emit_signal("continue_pressed")
