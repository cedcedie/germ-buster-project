extends Node

signal level_changed(level_index)
signal game_completed

var current_level_index: int = 0
var total_stars: int = 0
var max_unlocked_level: int = 0
var last_played_level: int = 0

var levels: Array[String] = [
	"res://Scenes/Level1.tscn",
	"res://Scenes/Level2.tscn",
	"res://Scenes/Level3.tscn",
	"res://Scenes/Level4.tscn"
]

const SAVE_PATH = "user://savegame.save"

func _ready():
	load_game()

func _input(event):
	# Debug level switching
	if OS.is_debug_build():
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_1: load_level(0)
				KEY_2: load_level(1)
				KEY_3: load_level(2)
				KEY_4: load_level(3)
func start_game():
	current_level_index = 0
	total_stars = 0
	load_level(current_level_index)

func continue_game():
	# If we have a last played level, prioritize that
	# Otherwise, use the max unlocked level index
	var target_level = last_played_level
	if target_level >= levels.size():
		target_level = levels.size() - 1
		
	load_level(target_level)

func load_level(index: int):
	if index >= 0 and index < levels.size():
		current_level_index = index
		last_played_level = index # Track where the user is
		save_game()
		get_tree().change_scene_to_file(levels[index])
		emit_signal("level_changed", index)
		# Auto-apply font to new scene
		await get_tree().process_frame
		if get_tree().current_scene:
			apply_font_to_ui(get_tree().current_scene)
	else:
		print("Error: Level index out of bounds")

func apply_font_to_ui(node: Node):
	if not node: return # Null check to prevent errors
	
	var game_font = load("res://Daily Vibes.otf")
	if not game_font: return
	
	if node is Label:
		node.add_theme_font_override("font", game_font)
	elif node is Button:
		node.add_theme_font_override("font", game_font)
	elif node is RichTextLabel:
		node.add_theme_font_override("font", game_font)
	
	for child in node.get_children():
		apply_font_to_ui(child)

func complete_level(level_index: int):
	# Unlock next level
	var next_index = level_index + 1
	
	# Don't unlock beyond the total count of levels
	if next_index > levels.size():
		next_index = levels.size()
		
	if next_index > max_unlocked_level:
		max_unlocked_level = next_index
		
	# On completion, we ideally want 'continue' to point to the next level
	# unless they've finished everything.
	if next_index < levels.size():
		last_played_level = next_index
	else:
		last_played_level = level_index # Keep them on the last level if done
		
	save_game()

func next_level():
	complete_level(current_level_index)
	current_level_index += 1
	if current_level_index < levels.size():
		load_level(current_level_index)
	else:
		emit_signal("game_completed")
		# Maybe go to main menu or credits?
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
		print("Game Completed!")

func spawn_sparkle(pos: Vector2):
	var sparkle_scene = load("res://Scenes/Sparkle.tscn")
	if sparkle_scene:
		var sparkle = sparkle_scene.instantiate()
		sparkle.position = pos
		get_tree().current_scene.add_child(sparkle)

func spawn_germ_particles(parent: Node, area_extents: Vector2, amount: int = 15, scale_range: Vector2 = Vector2(4, 8)) -> CPUParticles2D:
	var germs = CPUParticles2D.new()
	parent.add_child(germs)
	germs.amount = amount
	germs.lifetime = 1.5
	germs.preprocess = 1.0
	germs.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	germs.emission_rect_extents = area_extents
	germs.gravity = Vector2.ZERO
	germs.initial_velocity_min = 5
	germs.initial_velocity_max = 20
	germs.scale_amount_min = scale_range.x
	germs.scale_amount_max = scale_range.y
	germs.color = Color(0.2, 0.8, 0.2, 0.7)
	germs.spread = 180
	return germs

func shake_camera(intensity: float = 5.0, duration: float = 0.2):
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	var original_offset = camera.offset
	var tween = create_tween()
	for i in range(4):
		var rand_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", original_offset + rand_offset, duration / 5.0)
	tween.tween_property(camera, "offset", original_offset, duration / 5.0)

func add_stars(amount: int):
	total_stars += amount
	print("Total Stars: ", total_stars)

func restart_level():
	load_level(current_level_index)

# --- Save System ---
func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data = {
			"max_unlocked_level": max_unlocked_level,
			"last_played_level": last_played_level,
			"total_stars": total_stars
		}
		file.store_string(JSON.stringify(data))
		print("Game Saved. Max Level: ", max_unlocked_level)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var data = json.get_data()
			if data.has("max_unlocked_level"):
				max_unlocked_level = int(data["max_unlocked_level"])
			if data.has("last_played_level"):
				last_played_level = int(data["last_played_level"])
			if data.has("total_stars"):
				total_stars = int(data["total_stars"])
			print("Game Loaded. Max Level: ", max_unlocked_level)

func style_button(button: Button, color_type: String = "blue"):
	if not button: return
	
	var normal_style = StyleBoxFlat.new()
	var hover_style: StyleBoxFlat
	var pressed_style: StyleBoxFlat
	
	# Base colors
	var base_color: Color
	var border_color: Color
	
	match color_type:
		"blue":
			base_color = Color(0.15, 0.55, 0.9, 1.0)
			border_color = Color(0.1, 0.4, 0.7, 1.0)
		"green":
			base_color = Color(0.2, 0.7, 0.3, 1.0)
			border_color = Color(0.15, 0.5, 0.2, 1.0)
		"red":
			base_color = Color(0.8, 0.3, 0.3, 1.0)
			border_color = Color(0.6, 0.2, 0.2, 1.0)
		"yellow":
			base_color = Color(0.9, 0.7, 0.1, 1.0)
			border_color = Color(0.7, 0.5, 0.05, 1.0)
		"purple":
			base_color = Color(0.6, 0.4, 0.8, 1.0)
			border_color = Color(0.4, 0.2, 0.6, 1.0)
		_: # Default to blue
			base_color = Color(0.15, 0.55, 0.9, 1.0)
			border_color = Color(0.1, 0.4, 0.7, 1.0)

	normal_style.bg_color = base_color
	normal_style.set_corner_radius_all(15)
	normal_style.shadow_size = 4
	normal_style.shadow_color = Color(0, 0, 0, 0.2)
	normal_style.border_width_bottom = 4
	normal_style.border_color = border_color
	
	hover_style = normal_style.duplicate()
	hover_style.bg_color = base_color.lightened(0.2)
	
	pressed_style = normal_style.duplicate()
	pressed_style.bg_color = base_color.darkened(0.2)
	pressed_style.border_width_bottom = 1
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Hover animation logic if not already present
	if not button.mouse_entered.is_connected(_on_button_hover_generalized.bind(button, true)):
		button.mouse_entered.connect(_on_button_hover_generalized.bind(button, true))
		button.mouse_exited.connect(_on_button_hover_generalized.bind(button, false))
	
	button.pivot_offset = button.size / 2

func _on_button_hover_generalized(button: Button, is_hovering: bool):
	var tween = button.create_tween()
	var target_scale = Vector2(1.05, 1.05) if is_hovering else Vector2(1.0, 1.0)
	tween.tween_property(button, "scale", target_scale, 0.1).set_trans(Tween.TRANS_SINE)
