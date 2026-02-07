extends Node



signal level_changed(level_index)
signal game_completed

var current_level_index: int = 0
var total_stars: int = 0
var levels: Array[String] = [
	"res://Scenes/Level1.tscn",
	"res://Scenes/Level2.tscn",
	"res://Scenes/Level3.tscn",
	"res://Scenes/Level4.tscn"
]

func _ready():
	pass

func start_game():
	current_level_index = 0
	total_stars = 0
	load_level(current_level_index)

func load_level(index: int):
	if index >= 0 and index < levels.size():
		current_level_index = index
		get_tree().change_scene_to_file(levels[index])
		emit_signal("level_changed", index)
	else:
		print("Error: Level index out of bounds")

func next_level():
	current_level_index += 1
	if current_level_index < levels.size():
		load_level(current_level_index)
	else:
		emit_signal("game_completed")
		get_tree().change_scene_to_file("res://Scenes/CompletionScreen.tscn")
		print("Game Completed!")

func spawn_sparkle(pos: Vector2):
	var sparkle_scene = load("res://Scenes/Sparkle.tscn")
	var sparkle = sparkle_scene.instantiate()
	sparkle.position = pos
	# Add to current scene
	get_tree().current_scene.add_child(sparkle)

func add_stars(amount: int):
	total_stars += amount
	print("Total Stars: ", total_stars)

func restart_level():
	load_level(current_level_index)
