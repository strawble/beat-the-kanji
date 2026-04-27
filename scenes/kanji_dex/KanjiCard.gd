extends PanelContainer

@onready var char_label    : Label = $CardVBox/CharLabel
@onready var meaning_label : Label = $CardVBox/MeaningLabel
@onready var kun_label     : Label = $CardVBox/KunLabel
@onready var on_label      : Label = $CardVBox/OnLabel

func setup(kanji: Dictionary, discovered: bool) -> void:
	if not discovered:
		_show_locked()
		return
	_show_unlocked(kanji)

func _show_locked() -> void:
	char_label.text    = "?"
	meaning_label.text = "???"
	kun_label.text     = ""
	on_label.text      = ""
	# Teinte grisée pour les cartes verrouillées
	modulate = Color(0.5, 0.5, 0.5, 0.8)

func _show_unlocked(kanji: Dictionary) -> void:
	modulate = Color.WHITE
	char_label.text    = kanji["character"]
	meaning_label.text = ", ".join(kanji["meanings"])

	if not kanji["kun_yomi"].is_empty():
		kun_label.text = "kun : " + "、".join(kanji["kun_yomi"])
	else:
		kun_label.text = ""

	if not kanji["on_yomi"].is_empty():
		on_label.text = "on : " + "、".join(kanji["on_yomi"])
	else:
		on_label.text = ""
