extends Control

@onready var stars_label = $Panel/StarsLabel

func _ready():
	stars_label.text = "Stars Earned: " + str(GameManager.total_stars)

func _on_RestartButton_pressed():
	GameManager.start_game()
