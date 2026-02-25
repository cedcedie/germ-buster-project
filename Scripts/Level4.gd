extends Node2D

@onready var mouth_anim = $AnimatedSprite2D
@onready var floss = $Sprite2D
@onready var dialogue_box = $UI/DialogueBox
@onready var checklist_label = $UI/ChecklistLabel
@onready var progress_bar = $UI/FlossingProgressBar

# Audio
@onready var sfx_player = $AudioPlayers/SFXPlayer if has_node("AudioPlayers/SFXPlayer") else null
var sfx_correct: AudioStream
var music_player: AudioStreamPlayer

# State variables
var current_gap_index: int = 0
var is_dragging_floss: bool = false
var floss_offset: Vector2 = Vector2.ZERO
var floss_start_pos: Vector2
var swipe_timer: float = 0.0
var required_swipe_duration: float = 1.5 
var last_mouse_pos: Vector2 = Vector2.ZERO

# Gap Configuration
@onready var gaps = [
	$AnimatedSprite2D/Area2D,
	$AnimatedSprite2D/Area2D2,
	$AnimatedSprite2D/Area2D3,
	$AnimatedSprite2D/Area2D4,
	$AnimatedSprite2D/Area2D5,
	$AnimatedSprite2D/Area2D6,
	$AnimatedSprite2D/Area2D7,
	$AnimatedSprite2D/Area2D8,
	$AnimatedSprite2D/Area2D9,
	$AnimatedSprite2D/Area2D10
]

# Frame transitions
var gap_frame_targets = [
	[0, 1, 2],      # Area2D: 0 to 2
	[2, 3, 4, 5],   # Area2D2: 2 to 5
	[5, 6, 7],      # Area2D3: 5 to 7
	[7, 8, 9, 10],      # Area2D4: 7 to 9
	[10, 11],    # Area2D5: 9 to 11
	[11, 12],       # Area2D6: 11 to 12
	[12, 13],       # Area2D7: 12 to 13
	[13, 14, 15],   # Area2D8: 13 to 15
	[15, 16],       # Area2D9: 15 to 16
	[16, 17, 18]    # Area2D10: 16 to 18
]

func _ready():
	floss_start_pos = floss.position
	mouth_anim.frame = 0
	
	_load_audio()
	
	# Start Background Music
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	music_player.stream = load("res://Assets/Audio/SFX/sans. - toby fox - SoundLoadMate.com.mp3")
	music_player.bus = "Master"
	music_player.play()
	# Looping
	music_player.finished.connect(func(): music_player.play())
	
	# Enable first gap
	for i in range(gaps.size()):
		gaps[i].get_node("CollisionShape2D").disabled = (i != 0)
	
	if progress_bar:
		progress_bar.visible = false
		progress_bar.max_value = required_swipe_duration
		
	update_ui_text()
	
	# Initial instruction
	await get_tree().create_timer(1.0).timeout
	update_instructions("Let's floss! The order is top left to right, then lower left to lower right.", "talking")
	await get_tree().create_timer(4.0).timeout
	update_instructions("Drag the floss to the first gap and swipe back and forth!", "talking")

func _load_audio():
	sfx_correct = load("res://Assets/Audio/SFX/step_complete.mp3")

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var mouse_pos = get_global_mouse_position()
				if mouse_pos.distance_to(floss.global_position) < 150:
					is_dragging_floss = true
					floss_offset = floss.global_position - mouse_pos
					remove_glow_pulse()
			else:
				is_dragging_floss = false
				if swipe_timer < required_swipe_duration:
					_return_floss()
				if progress_bar: progress_bar.visible = false

func _process(delta):
	if is_dragging_floss:
		var mouse_pos = get_global_mouse_position()
		floss.global_position = mouse_pos + floss_offset
		
		# Check if over current gap
		if current_gap_index < gaps.size():
			var current_gap = gaps[current_gap_index]
			var floss_area = _get_floss_area()
			
			if floss_area and current_gap.overlaps_area(floss_area):
				_handle_swiping(delta)
			else:
				if progress_bar: progress_bar.visible = false
	
	last_mouse_pos = get_global_mouse_position()

func _get_floss_area() -> Area2D:
	return floss.get_node_or_null("Area2D")

func _handle_swiping(delta):
	var mouse_velocity = (get_global_mouse_position() - last_mouse_pos).length()
	
	if mouse_velocity > 5: 
		if progress_bar:
			progress_bar.visible = true
			progress_bar.value = swipe_timer
			
		swipe_timer += delta
		
		# Update animation frames based on progress
		var targets = gap_frame_targets[current_gap_index]
		var progress_ratio = swipe_timer / required_swipe_duration
		var frame_idx = int(progress_ratio * (targets.size() - 1))
		mouth_anim.frame = targets[frame_idx]
		
		if swipe_timer >= required_swipe_duration:
			_complete_gap()

func _complete_gap():
	swipe_timer = 0.0
	if progress_bar: progress_bar.visible = false
	
	# Final frame for this gap
	var targets = gap_frame_targets[current_gap_index]
	mouth_anim.frame = targets.back()
	
	# Play Correct Sound
	if sfx_player and sfx_correct:
		sfx_player.stream = sfx_correct
		sfx_player.play()
	
	GameManager.shake_camera(3.0, 0.1) # Add juice on gap completion
	
	current_gap_index += 1
	update_ui_text()
	
	if current_gap_index < gaps.size():
		# Enable next gap
		for i in range(gaps.size()):
			gaps[i].get_node("CollisionShape2D").disabled = (i != current_gap_index)
		update_instructions("Nice! Swipe some more for the next gap.", "correct")
	else:
		_finish_level()

func _return_floss():
	var tween = create_tween()
	tween.tween_property(floss, "position", floss_start_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _finish_level():
	update_instructions("Sparkling clean! Great job flossing!", "correct")
	# Spawn sparkles
	if GameManager.has_method("spawn_sparkle"):
		for i in range(15):
			GameManager.spawn_sparkle(mouth_anim.global_position + Vector2(randf_range(-150, 150), randf_range(-100, 100)))
			await get_tree().create_timer(0.15).timeout
	
	# Show completion modal
	var completion_modal = get_node_or_null("UI/CompletionModal")
	if completion_modal:
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

		var menu_btn = completion_modal.find_child("MenuButton", true, false)
		if menu_btn:
			GameManager.style_button(menu_btn, "blue")
			if not menu_btn.pressed.is_connected(_on_menu_pressed):
				menu_btn.pressed.connect(_on_menu_pressed)
	else:
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_menu_pressed():
	if music_player: music_player.stop()
	GameManager.complete_level(3) # Level 4 index
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func update_instructions(text: String, type: String = "talking"):
	if dialogue_box and dialogue_box.has_method("show_text"):
		dialogue_box.show_text(text, type)

func update_ui_text():
	# Simple task list for Level 4 - Visible on top left ChecklistLabel
	var text = "Level 4: Flossing\n"
	text += "Tasks:\n"
	text += "[x] " if current_gap_index == gaps.size() else "[o] "
	text += "Clean all gaps (%d/%d)" % [current_gap_index, gaps.size()]
	if checklist_label:
		checklist_label.text = text

# ===== VISUAL HELPERS =====
var active_glow_tween: Tween

func add_glow_pulse(node: CanvasItem):
	remove_glow_pulse()
	if not node: return
	active_glow_tween = create_tween()
	active_glow_tween.set_loops()
	active_glow_tween.tween_property(node, "modulate", Color(1.3, 1.3, 1.3), 0.8).set_trans(Tween.TRANS_SINE)
	active_glow_tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

func remove_glow_pulse():
	if active_glow_tween:
		active_glow_tween.kill()
		active_glow_tween = null
	floss.modulate = Color(1,1,1)
