extends PanelContainer

# Card shown in the KanjiDex. Displays:
#  - the kanji character (or '?' if not yet discovered)
#  - its meanings (English)
#  - its kun and on readings (Japanese)
#  - mastery stars based on the player's current mastery score for this kanji

@onready var char_label    : Label = $CardVBox/CharLabel
@onready var meaning_label : Label = $CardVBox/MeaningLabel
@onready var kun_label     : Label = $CardVBox/KunLabel
@onready var on_label      : Label = $CardVBox/OnLabel
@onready var stars_label   : Label = $CardVBox/StarsLabel

# Mastery thresholds for 1, 2, 3 stars (each correct answer = +0.15)
const STAR_1 : float = 0.30
const STAR_2 : float = 0.60
const STAR_3 : float = 0.90

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
	stars_label.text   = "☆☆☆"
	stars_label.modulate = Color(0.55, 0.55, 0.55, 1.0)
	# Greyed tint for locked cards
	modulate = Color(0.5, 0.5, 0.5, 0.8)

func _show_unlocked(kanji: Dictionary) -> void:
	modulate = Color.WHITE
	char_label.text    = kanji["character"]
	meaning_label.text = ", ".join(kanji["meanings"])

	if not kanji["kun_yomi"].is_empty():
		kun_label.text = "kun: " + "、".join(kanji["kun_yomi"])
	else:
		kun_label.text = ""

	if not kanji["on_yomi"].is_empty():
		on_label.text = "on: " + "、".join(kanji["on_yomi"])
	else:
		on_label.text = ""

	_set_stars(int(kanji["id"]))

func _set_stars(kanji_id: int) -> void:
	var mastery := GameManager.get_mastery(kanji_id)
	var earned := 0
	if mastery >= STAR_1: earned += 1
	if mastery >= STAR_2: earned += 1
	if mastery >= STAR_3: earned += 1

	var text := ""
	for i in range(3):
		text += "★" if i < earned else "☆"
	stars_label.text = text

	# Color: yellow if partial, green when fully mastered
	if earned == 3:
		stars_label.modulate = Color(0.4, 1.0, 0.5)
	elif earned > 0:
		stars_label.modulate = Color(1.0, 0.85, 0.3)
	else:
		stars_label.modulate = Color(0.6, 0.6, 0.6)
