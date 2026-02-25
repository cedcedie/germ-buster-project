extends Node2D

@onready var level_manager = $LevelManager
@onready var dialogue_box = $UI/DialogueBox
@onready var checklist_label = $UI/ChecklistLabel

# Game Objects
@onready var faucet_area = $Faucet
@onready var faucet_water_sprite = $Faucet/AnimatedSprite2D2
@onready var toothbrush = $toothbrush
@onready var toothpaste = $toothpaste
@onready var dirty_mouth = $dirty_mouth
@onready var clean_mouth = $clean_mouth

# New UI
@onready var progress_bar = $UI/BrushingProgressBar

# Audio Streams
var sfx_wet: AudioStream
var sfx_pop: AudioStream
var sfx_squeeze: AudioStream
var sfx_step_complete: AudioStream
var sfx_level_complete: AudioStream
var sfx_wrong: AudioStream
var sfx_brushing_loop: AudioStream
var brushing_player: AudioStreamPlayer
var water_player: AudioStreamPlayer

# Audio Player Node (for One-Shots)
@onready var sfx_player = $AudioPlayers/SFXPlayer if has_node("AudioPlayers/SFXPlayer") else null

# State Variables
var current_step: int = 0 # 0: Wet, 1: Open Paste, 2: Apply Paste, 3: Brush
var is_brush_wet: bool = false
var is_paste_open: bool = false
var has_paste: bool = false
var is_brushing: bool = false
var brushing_timer: float = 0.0
var required_brushing_duration: float = 15.0 # 20 seconds

# Dragging State
var is_dragging_brush: bool = false
var is_dragging_paste: bool = false # Not strictly needed if we only click paste, but good for consistency
var brush_start_pos: Vector2
var brush_offset: Vector2
var mouth_base_pos: Vector2

# Step Constants
const STEP_WET_BRUSH = 0
const STEP_OPEN_PASTE = 1
const STEP_APPLY_PASTE = 2
const STEP_BRUSH_TEETH = 3

func _ready():
	_load_audio()
	
	# Create Brushing Loop Player
	brushing_player = AudioStreamPlayer.new()
	brushing_player.stream = sfx_brushing_loop
	brushing_player.autoplay = false
	brushing_player.bus = "Master"
	add_child(brushing_player)

	# Stop any lingering SFX
	if sfx_player: sfx_player.stop()

	# Start Background Music
	var music_player = $AudioPlayers/MusicPlayer
	if music_player:
		music_player.stream = load("res://Assets/Audio/Snowy.mp3")
		music_player.play()

	# Start Water Loop (Permanent for Level 3)
	water_player = AudioStreamPlayer.new()
	water_player.stream = sfx_wet # Reusing the loaded faucet sound
	water_player.bus = "Master"
	add_child(water_player)
	water_player.play()
	# Check if we need to manually loop it (if the .import doesn't have loop on)
	water_player.finished.connect(func(): water_player.play())

	# Initialize Nodes
	brush_start_pos = toothbrush.position
	mouth_base_pos = dirty_mouth.position
	clean_mouth.visible = false
	clean_mouth.modulate.a = 0
	dirty_mouth.visible = true
	
	# Setup Toothbrush
	var brush_sprite = toothbrush.get_node("AnimatedSprite2D")
	if brush_sprite: brush_sprite.frame = 0 # Default (no paste)
	
	# Setup Toothpaste
	var paste_sprite = toothpaste.get_node("AnimatedSprite2D")
	if paste_sprite: 
		paste_sprite.animation = "default"
		paste_sprite.frame = 0 # Closed
	
	# Connect Signals
	_connect_signals()
	
	# Initial UI
	update_ui_text()
	start_level_intro()
	
	# Reset Progress Bar
	if progress_bar:
		progress_bar.max_value = required_brushing_duration
		progress_bar.value = 0
		progress_bar.visible = false

	# Ensure running water is hidden initially if Faucet logic mimics Level 1
	if faucet_water_sprite:
		faucet_water_sprite.visible = true # As per user request "Water should automatically run"
		faucet_water_sprite.play("faucet_impact")

	# Initial Glow: Pulse Brush
	if brush_sprite:
		add_glow_pulse(brush_sprite)

func _load_audio():
	# Load standard SFX
	sfx_wet = load("res://Assets/Audio/SFX/faucet.mp3") 
	sfx_pop = load("res://Assets/Audio/SFX/button_click.mp3") 
	sfx_squeeze = load("res://Assets/Audio/SFX/step_complete.mp3") 
	
	sfx_step_complete = load("res://Assets/Audio/SFX/step_complete.mp3")
	sfx_level_complete = load("res://Assets/Audio/SFX/level_complete.mp3")
	sfx_wrong = load("res://Assets/Audio/SFX/wrong_item.mp3")
	
	sfx_brushing_loop = load("res://Assets/Audio/Brushing Teeth Sound Effect.mp3")

func _play_sfx(name: String):
	if not sfx_player: return
	
	var stream_to_play = null
	match name:
		"wet": stream_to_play = sfx_wet
		"pop": stream_to_play = sfx_pop
		"squeeze": stream_to_play = sfx_squeeze
		"correct": stream_to_play = sfx_step_complete
		"level_complete": stream_to_play = sfx_level_complete
		"wrong": stream_to_play = sfx_wrong
	
	if stream_to_play:
		sfx_player.stream = stream_to_play
		sfx_player.play()

func _connect_signals():
	if level_manager:
		level_manager.step_completed.connect(_on_step_completed)
	
	# Connect Input Events
	toothbrush.input_event.connect(_on_toothbrush_input)
	toothpaste.input_event.connect(_on_toothpaste_input)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				_handle_mouse_up()

func _on_toothbrush_input(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_dragging_brush = true
		brush_offset = toothbrush.global_position - get_global_mouse_position()
		remove_glow_pulse() # Stop pulsing when interaction starts

func _on_toothpaste_input(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if current_step == STEP_OPEN_PASTE:
			_complete_step_open_paste()

func _handle_mouse_up():
	if is_dragging_brush:
		is_dragging_brush = false
		_handle_brush_drop()
		if current_step != STEP_BRUSH_TEETH: 
			_return_brush_to_start()
			
			# Stop audio if we dropped it
			if brushing_player.playing:
				brushing_player.stop()

func _process(delta):
	# Handle Dragging
	if is_dragging_brush:
		toothbrush.global_position = get_global_mouse_position() + brush_offset
		
		# Brushing Logic
		if current_step == STEP_BRUSH_TEETH:
			_check_brushing_progress(delta)

func _check_brushing_progress(delta):
	# Use Area2D overlap check
	if dirty_mouth.overlaps_area(toothbrush):
		# Show Progress Bar
		if progress_bar and not progress_bar.visible:
			progress_bar.visible = true
			
		# Track Movement
		var mouse_velocity = Input.get_last_mouse_velocity().length()
		
		# Threshold: Must be moving to count as brushing
		if mouse_velocity > 100: 
			# Increment time (active brushing time)
			brushing_timer += delta
			
			# Update Bar
			if progress_bar:
				progress_bar.value = brushing_timer
			
			# Visuals: Play Animation
			var mouth_sprite = dirty_mouth.get_node("AnimatedSprite2D")
			if mouth_sprite and mouth_sprite.sprite_frames.has_animation("default"):
				if not mouth_sprite.is_playing():
					mouth_sprite.play("default")
			
			# Visuals: Pulse Effect (Juice)
			var pulse_scale = 1.0 + (sin(Time.get_ticks_msec() * 0.02) * 0.05)
			dirty_mouth.scale = Vector2(0.9, 0.9) * pulse_scale

			# Shake
			var shake_offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
			dirty_mouth.position = mouth_base_pos + shake_offset
			
			# Audio: Resume looping sound
			if not brushing_player.playing:
				brushing_player.play()
			if brushing_player.stream_paused:
				brushing_player.stream_paused = false
				
			# Completion
			if brushing_timer >= required_brushing_duration:
				_complete_step_brush_teeth()
				
			# Add shake while brushing
			if int(Time.get_ticks_msec() / 100) % 2 == 0:
				GameManager.shake_camera(2.0, 0.05)
				
		else:
			# Wrapped in else to handle "Stopped moving" state
			_pause_brushing_effects()
	else:
		# Not overlapping
		_pause_brushing_effects()

func _pause_brushing_effects():
	if brushing_player.playing:
		brushing_player.stream_paused = true
	
	var mouth_sprite = dirty_mouth.get_node("AnimatedSprite2D")
	if mouth_sprite: 
		mouth_sprite.pause() # Pause instead of stop to keep frame
		
	dirty_mouth.position = mouth_base_pos
	dirty_mouth.scale = Vector2(0.9, 0.9) # Reset scale

func _handle_brush_drop():
	# Step 1: Wet Brush
	if current_step == STEP_WET_BRUSH:
		if _check_overlap(toothbrush, faucet_area):
			_complete_step_wet_brush()
	
	# Step 3: Apply Paste
	elif current_step == STEP_APPLY_PASTE:
		if _check_overlap(toothbrush, toothpaste):
			_complete_step_apply_paste()

func _check_overlap(node_a: Node2D, node_b: Node2D) -> bool:
	# Keep helper for non-Area2D checks if any (Faucet is Area2D now)
	if node_a is Area2D and node_b is Area2D:
		return node_a.overlaps_area(node_b)
	return node_a.global_position.distance_to(node_b.global_position) < 100.0

# ===== VISUAL HELPERS =====
var active_glow_tween: Tween

func add_glow_pulse(node: CanvasItem):
	remove_glow_pulse()
	if not node: return
	
	active_glow_tween = create_tween()
	active_glow_tween.set_loops()
	# Pulse brightness up and down
	active_glow_tween.tween_property(node, "modulate", Color(1.5, 1.5, 1.5), 0.8).set_trans(Tween.TRANS_SINE)
	active_glow_tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

func remove_glow_pulse():
	if active_glow_tween:
		active_glow_tween.kill()
		active_glow_tween = null
	
	# Reset potential targets to normal color
	var brush_sprite = toothbrush.get_node("AnimatedSprite2D")
	if brush_sprite: brush_sprite.modulate = Color(1,1,1)
	
	var paste_sprite = toothpaste.get_node("AnimatedSprite2D")
	if paste_sprite: paste_sprite.modulate = Color(1,1,1)
	
	var faucet_sprite = faucet_area.get_node("AnimatedSprite2D")
	if faucet_sprite: faucet_sprite.modulate = Color(1,1,1)

# --- Step Completion Logic ---

func _complete_step_wet_brush():
	is_brush_wet = true
	faucet_water_sprite.visible = true 
	current_step = STEP_OPEN_PASTE
	update_instruction("Nice! Now tap the toothpaste to open it.", "correct")
	_play_sfx("correct") # Play success chime
	update_ui_text()
	
	# Highlight Toothpaste next
	var paste_sprite = toothpaste.get_node("AnimatedSprite2D")
	add_glow_pulse(paste_sprite)

func _complete_step_open_paste():
	is_paste_open = true
	var sprite = toothpaste.get_node("AnimatedSprite2D")
	if sprite: sprite.frame = 1 
	current_step = STEP_APPLY_PASTE
	update_instruction("Good! Now drag the brush to the toothpaste.", "correct")
	_play_sfx("correct") # Play success chime
	update_ui_text()
	
	# Highlight Toothbrush
	var brush_sprite = toothbrush.get_node("AnimatedSprite2D")
	add_glow_pulse(brush_sprite)

func _complete_step_apply_paste():
	has_paste = true
	var sprite = toothbrush.get_node("AnimatedSprite2D")
	if sprite: sprite.frame = 1
	current_step = STEP_BRUSH_TEETH
	update_instruction("Ready! Brush those teeth thoroughly.", "correct")
	_play_sfx("correct") # Play success chime
	update_ui_text()
	
	# Show bar
	if progress_bar: progress_bar.visible = true
	
	# Highlight Brush again for final step
	var brush_sprite = toothbrush.get_node("AnimatedSprite2D")
	add_glow_pulse(brush_sprite)

func _complete_step_brush_teeth():
	is_brushing = false
	current_step = 4 
	
	remove_glow_pulse() # Stop glowing
	
	if brushing_player: brushing_player.stop()
	if progress_bar: progress_bar.visible = false
	
	dirty_mouth.visible = false
	clean_mouth.visible = true
	var tween = create_tween()
	tween.tween_property(clean_mouth, "modulate:a", 1.0, 0.5)
	
	# Play Victory Sound
	_play_sfx("level_complete")
	
	# Sparkles
	for i in range(10):
		GameManager.spawn_sparkle(clean_mouth.global_position + Vector2(randf_range(-50, 50), randf_range(-30, 30)))
		await get_tree().create_timer(0.1).timeout
	
	update_instruction("Sparkling clean! Great job!", "correct")
	update_ui_text()
	
	await get_tree().create_timer(2.0).timeout
	_show_completion()

func _show_completion():
	var completion_modal = $UI/CompletionModal
	completion_modal.visible = true
	
	# Stylize Panel
	var panel = completion_modal.get_node_or_null("Panel")
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.3, 0.4, 0.95)
		style.set_corner_radius_all(20)
		style.shadow_size = 10
		style.shadow_color = Color(0, 0, 0, 0.5)
		panel.add_theme_stylebox_override("panel", style)
		
		panel.scale = Vector2(0.1, 0.1)
		panel.pivot_offset = panel.size / 2
		var tween = create_tween()
		tween.tween_property(panel, "scale", Vector2(1, 1), 0.5).set_trans(Tween.TRANS_BACK)

	var next_btn = completion_modal.find_child("NextLevelButton", true, false)
	var menu_btn = completion_modal.find_child("MenuButton", true, false)
	
	if next_btn:
		GameManager.style_button(next_btn, "green")
		if not next_btn.pressed.is_connected(_on_next_level_pressed):
			next_btn.pressed.connect(_on_next_level_pressed)
	if menu_btn:
		GameManager.style_button(menu_btn, "blue")
		if not menu_btn.pressed.is_connected(_on_menu_pressed):
			menu_btn.pressed.connect(_on_menu_pressed)

func _on_next_level_pressed():
	if water_player: water_player.stop()
	_play_sfx("pop")
	GameManager.complete_level(2)
	get_tree().change_scene_to_file("res://Scenes/Level4.tscn")

func _on_menu_pressed():
	if water_player: water_player.stop()
	_play_sfx("pop")
	GameManager.complete_level(2)
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _return_brush_to_start():
	var tween = create_tween()
	tween.tween_property(toothbrush, "global_position", brush_start_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func start_level_intro():
	update_instruction("Let's brush! First, wet the toothbrush.", "talking")

func update_instruction(text: String, type: String = "talking"):
	if dialogue_box:
		dialogue_box.visible = true
		dialogue_box.show_text(text, type)
		

func update_ui_text():
	var tasks = [
		"1. Wet toothbrush",
		"2. Open toothpaste",
		"3. Apply toothpaste",
		"4. Brush teeth"
	]
	var text = "Tasks:\n"
	if checklist_label:
		for i in range(tasks.size()):
			if i < current_step:
				text += "[x] " + tasks[i] + "\n"
			elif i == current_step:
				text += "[o] " + tasks[i] + "\n"
			else:
				text += "[ ] " + tasks[i] + "\n"
		checklist_label.text = text

func _on_step_completed(step_index):
	update_ui_text()
