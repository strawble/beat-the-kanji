extends Node2D

@onready var back_button : Button = $UI/Root/VBox/BackButton

func _ready() -> void:
	NavBar.hide_navbar()
	back_button.pressed.connect(_on_back)

func _on_back() -> void:
	GameManager.go_to("res://scenes/main_menu/MainMenu.tscn")
