extends Node2D

@onready var level_manager = $LevelManager

# Animated Sprites
@onready var hand_cutting = $HandCutting
@onready var hand_filing = $HandFiling
@onready var nail_cutter_anim = $NailCutter/AnimatedSprite2D
@onready var nail_file_sprite = $NailFile/Sprite2D # This might be causing issues if structure changed

@onready var checklist_label = $UI/ChecklistLabel
var timer_label: Label
var game_timer: Timer

# Interaction Areas
@onready var finger_areas = $FingerAreas.get_children()
@onready var filing_areas = [
	$HandFiling/left,
	$HandFiling/right
]

@onready var nail_cutter = $NailCutter
@onready var nail_file = $NailFile

# Shape identifier for the nail tip
var nail_tip_shape_idx: int = -1

# Audio
var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var cut_sound: AudioStream
var file_sound: AudioStream
var error_sound: AudioStream
var complete_sound: AudioStream
var victory_sound: AudioStream

# State
var current_cutting_frame = 0 
var max_cutting_frames = 10 
var completion_screen
var dialogue_box
var tip_is_over_finger: Area2D = null
# Finger Names
var finger_names = [
	"Left Thumb", "Left Index", "Left Middle", "Left Ring", "Left Pinky",
	"Right Thumb", "Right Index", "Right Middle", "Right Ring", "Right Pinky"
]

func _ready():
	_setup_audio()
	_setup_ui()
	
	level_manager.connect("step_completed", _on_step_completed)
	
	# Connect Finger Areas: Disable pickable so they don't intercept clicks
	# We will handle cutting with a global tip check instead.
	for i in range(finger_areas.size()):
		var area = finger_areas[i]
		area.input_pickable = false
	# Connect Filing Areas
	for area in filing_areas:
		area.input_pickable = true
		area.connect("input_event", func(_vp, ev, _idx): 
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_area_clicked(area, -1)
		)
	
	# Connect Tools for initial pickup
	nail_cutter.input_event.connect(func(_vp, ev, _idx): _check_tool_pickup(nail_cutter, ev))
	nail_file.input_event.connect(func(_vp, ev, _idx): _check_tool_pickup(nail_file, ev))
	
	# Ensure physics monitoring is active and masks are permissive
	nail_cutter.monitoring = true
	nail_cutter.monitorable = true
	nail_cutter.collision_mask = 0xFFFFFFFF
	for area in finger_areas:
		area.monitoring = true
		area.monitorable = true
		area.collision_layer = 1 # Put fingers on layer 1
	# Connect Collision Signals for the 'NailCutter' to track the 'nail_tip'
	_setup_nail_tip_logic()
	
	# Initial State
	hand_cutting.visible = true
	hand_cutting.frame = 0
	
	# Find the tip node recursively and set up its parenting
	_setup_nail_tip_logic()
	
	hand_filing.visible = false
	current_cutting_frame = 0
	
	# Disable filing areas initially
	for area in filing_areas:
		area.monitoring = false
		area.monitorable = false
	
	# Hand Entrance Animation (Off-screen -> 500)
	# User wants "from bottom to original position" (Simple slide)
	hand_cutting.position.y = 800 
	var entrance_tween = create_tween()
	entrance_tween.tween_property(hand_cutting, "position:y", 496.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Handle Fade In
	var fade_rect = get_node_or_null("TransitionLayer/FadeRect")
	if fade_rect:
		fade_rect.visible = true
		fade_rect.modulate.a = 1.0
		var fade_tween = create_tween()
		fade_tween.tween_property(fade_rect, "modulate:a", 0.0, 1.0)
		await fade_tween.finished
		fade_rect.visible = false
	
	# Setup tools for sticky behavior
	# nail_cutter.return_on_drop = false # Removed as per instruction
	nail_file.return_on_drop = false # Removed as per instruction
	
	update_ui_text()
	start_level_intro()
	
	# Start glowing the cutter initially
	add_glow_pulse(nail_cutter_anim)

func _setup_audio():
	# SFX
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	
	# Music
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	var music_stream = load("res://054 - Hotel.ogg")
	if music_stream:
		music_player.stream = music_stream
		music_player.volume_db = -10
		music_player.play()
	
	error_sound = load("res://Assets/Audio/SFX/wrong_item.mp3")
	complete_sound = load("res://Assets/Audio/SFX/step_complete.mp3")
	victory_sound = load("res://Assets/Audio/SFX/level_complete.mp3")
	
	if ResourceLoader.exists("res://Assets/Audio/SFX/cut.mp3"):
		cut_sound = load("res://Assets/Audio/SFX/cut.mp3")
	else:
		cut_sound = load("res://Assets/Audio/SFX/button_click.mp3")
		
	if ResourceLoader.exists("res://Assets/Audio/SFX/file.mp3"):
		file_sound = load("res://Assets/Audio/SFX/file.mp3")
	else:
		file_sound = load("res://Assets/Audio/SFX/step_complete.mp3")

func _setup_ui():
	# Check for DialogueBox at root (User placement) OR under UI
	if has_node("DialogueBox"):
		dialogue_box = $DialogueBox
	elif has_node("UI/DialogueBox"):
		dialogue_box = $UI/DialogueBox
		
	if dialogue_box and dialogue_box.has_signal("dialogue_hidden"):
		dialogue_box.dialogue_hidden.connect(_on_dialogue_hidden)
	
	# 2. Setup Timer and Label
	game_timer = Timer.new()
	game_timer.one_shot = true
	game_timer.timeout.connect(_on_timer_timeout)
	add_child(game_timer)
	
	timer_label = Label.new()
	timer_label.text = "Time: 20s"
	timer_label.position = Vector2(950, 580) # Bottom right
	timer_label.add_theme_font_size_override("font_size", 32)
	$UI.add_child(timer_label)

func _on_timer_timeout():
	_play_sfx(error_sound)
	update_instruction("Time's up! Let's try again.", "wrong")
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()

# ===== STICKY TOOL LOGIC =====
var active_tool: Node2D = null

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if active_tool == nail_cutter and level_manager.current_step == 0:
			# Check if the tip area is currently overlapping any finger
			if tip_is_over_finger:
				# Find index of the finger area
				var idx = finger_areas.find(tip_is_over_finger)
				if idx != -1:
					_on_finger_interaction(tip_is_over_finger, "NailCutter", idx)
				else:
					# Should not happen if logic is correct
					print("Error: Overlapping area is not in finger_areas")
			else:
				# Fallback manual check
				_check_tip_trigger_manual()
				
		elif active_tool == nail_file and level_manager.current_step == 1:
			_check_tip_trigger_file()

func _check_tip_trigger_manual():
	# If signal tracking missed it for some reason, check overlap manually
	for i in range(finger_areas.size()):
		var area = finger_areas[i]
		if _is_tip_on_nail_manual(area):
			_on_finger_interaction(area, "NailCutter", i)
			return
	
	print("Missed! Navigate the tip closer to the nail.")
	_play_sfx(error_sound)

func _check_tip_trigger_file():
	for area in filing_areas:
		# Use the same logic for filing for consistency
		if _is_tip_on_nail_manual(area):
			_on_filing_area_interaction(area, "NailFile")
			return

func _process(_delta):
	# Update timer label
	if !game_timer.is_stopped():
		timer_label.text = "Time: " + str(ceil(game_timer.time_left)) + "s"
	
	# Sticky tool behavior: Follow mouse if active
	if active_tool:
		active_tool.global_position = get_global_mouse_position()

# ===== VISUAL HELPERS =====
var active_glow_tween: Tween

func add_glow_pulse(node: CanvasItem):
	remove_glow_pulse()
	if not node: return
	
	active_glow_tween = create_tween()
	active_glow_tween.set_loops()
	active_glow_tween.tween_property(node, "modulate", Color(1.5, 1.5, 1.5), 0.8).set_trans(Tween.TRANS_SINE)
	active_glow_tween.tween_property(node, "modulate", Color(1.0, 1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

func remove_glow_pulse():
	if active_glow_tween:
		active_glow_tween.kill()
		active_glow_tween = null
	# Reset potential targets
	nail_cutter_anim.modulate = Color(1,1,1)
	if nail_file_sprite: nail_file_sprite.modulate = Color(1,1,1)

func _on_tool_picked_up(tool_node):
	remove_glow_pulse() # Stop glowing when they interact
	active_tool = tool_node
	tool_node.is_draggable = false # Disable standard dragging so it stays with us

func _on_area_clicked(area, index):
	if active_tool == nail_cutter and level_manager.current_step == 0:
		# Use robust tip validation
		if _is_tip_on_nail_manual(area):
			_on_finger_interaction(area, "NailCutter", index)
		else:
			print("Missed! Tip is not on nail.")
			_play_sfx(error_sound)
	elif active_tool == nail_file and level_manager.current_step == 1:
		_on_filing_area_interaction(area, "NailFile")

func _setup_nail_tip_logic():
	# search for 'nail_tip' under NailCutter specifically first
	var tip = nail_cutter.find_child("nail_tip", true, false)
	
	if not tip:
		print("Warning: 'nail_tip' not found on NailCutter. Checking children...")
		# Fallback search
		for child in nail_cutter.get_children():
			if "tip" in child.name.to_lower():
				tip = child
				break
	
	if tip:
		print("FOUND NAIL TIP: ", tip.name, " (", tip.get_class(), ")")
		
		# If it's a CollisionShape2D (the common case described by user)
		# We must wrap it in an Area2D to separate its logic from the main tool
		if tip is CollisionShape2D:
			print("Wrapping CollisionShape2D in separate TipArea...")
			var tip_area = Area2D.new()
			tip_area.name = "TipArea"
			
			# Add Area layer to cutter
			nail_cutter.add_child(tip_area)
			
			# Retain relative transform of the tip shape
			var original_transform = tip.transform
			
			# Re-parent the shape to the new Area
			tip.get_parent().remove_child(tip)
			tip_area.add_child(tip)
			
			# Apply transform
			tip.transform = original_transform
			# Adjust collision slightly higher as requested
			tip.position.y -= 15 
			
			_configure_tip_area(tip_area)
			
		elif tip is Area2D:
			print("Using existing Area2D as TipArea...")
			# Adjust position if it's already an Area2D
			tip.position.y -= 15
			_configure_tip_area(tip)
		else:
			print("Error: 'nail_tip' is neither CollisionShape2D nor Area2D.")
	else:
		print("CRITICAL: 'nail_tip' node NOT FOUND on NailCutter!")

func _configure_tip_area(area: Area2D):
	area.monitoring = true
	area.monitorable = true
	# Use Layer 2 for Tip interactions to avoid conflicts if needed, 
	# OR keep to Layer 1 if fingers are on Layer 1. 
	# Let's ensure they match.
	area.collision_layer = 1
	area.collision_mask = 1 
	
	# Connect signals
	if not area.area_entered.is_connected(_on_tip_entered):
		area.area_entered.connect(_on_tip_entered)
	if not area.area_exited.is_connected(_on_tip_exited):
		area.area_exited.connect(_on_tip_exited)
		
	# Store reference for manual checks logic
	area.add_to_group("ToolTip") 

func _on_tip_entered(area):
	if finger_areas.has(area) or filing_areas.has(area):
		print("Tip entered valid target: ", area.name)
		tip_is_over_finger = area

func _on_tip_exited(area):
	if tip_is_over_finger == area:
		print("Tip exited target: ", area.name)
		tip_is_over_finger = null

func _find_tip_recursive(node: Node) -> Node:
	# Keep for legacy/fallback search if needed
	if "tip" in node.name.to_lower():
		return node
	for child in node.get_children():
		var found = _find_tip_recursive(child)
		if found: return found
	return null

func _is_tip_on_nail_manual(target_area: Area2D) -> bool:
	# If signal worked
	if tip_is_over_finger == target_area:
		return true
		
	# Manual overlap check using the TipArea
	var tip_area = nail_cutter.find_child("TipArea", true, false)
	if not tip_area: tip_area = nail_cutter.find_child("nail_tip", true, false) as Area2D
	
	if tip_area and tip_area is Area2D:
		if tip_area.overlaps_area(target_area):
			return true
	
	# Fallback Distance Check
	var tip_node = nail_cutter.find_child("nail_tip", true, false)
	if tip_node:
		var dist = tip_node.global_position.distance_to(target_area.global_position)
		if dist < 100: 
			return true
			
	return false

func _release_active_tool():
	if active_tool:
		active_tool.is_draggable = true
		active_tool.return_to_start()
		active_tool = null

func start_level_intro():
	if dialogue_box:
		update_instruction("Let's start! Use the Nail Cutter on the Left Thumb.", "talking")

func update_instruction(text: String, type: String = "talking"):
	if dialogue_box:
		game_timer.stop()
		timer_label.visible = false
		dialogue_box.visible = true
		dialogue_box.show_text(text, type)
		

func _on_dialogue_hidden():
	if level_manager.current_step < 2:
		timer_label.visible = true
		if game_timer.is_stopped():
			if game_timer.time_left > 0:
				game_timer.start()
			else:
				game_timer.start(25.0)

func _on_finger_interaction(area, tool_name, finger_index):
	if level_manager.current_step == 0:
		if tool_name == "NailCutter":
			if finger_index == current_cutting_frame:
				_handle_cut(area)
			elif finger_index < current_cutting_frame:
				pass
			else:
				_play_sfx(error_sound)
				update_instruction("Wrong finger! Cut the " + finger_names[current_cutting_frame] + " next.", "wrong")
		elif tool_name == "NailFile":
			_play_sfx(error_sound)
			update_instruction("Cut first! Use the Nail Cutter.", "wrong")
	elif level_manager.current_step == 1:
		if tool_name == "NailCutter":
			_play_sfx(error_sound)
			update_instruction("Done cutting! Use the File to smooth them.", "wrong")

func _handle_cut(area):
	play_tool_anim("clip")
	_play_sfx(cut_sound)
	current_cutting_frame += 1
	GameManager.shake_camera(4.0, 0.1) # Add juice on cut
	var max_sprite_frames = hand_cutting.sprite_frames.get_frame_count("default") - 1
	var frame_to_show = current_cutting_frame
	if frame_to_show > max_sprite_frames:
		frame_to_show = max_sprite_frames
	hand_cutting.frame = frame_to_show
	spawn_debris_at_shape_center(area)
	
	if current_cutting_frame >= max_cutting_frames:
		_release_active_tool()
		_start_filing_phase()
	else:
		update_instruction("Good! Now cut the " + finger_names[current_cutting_frame] + ".")

func _check_tool_pickup(tool, event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if active_tool == null:
			_on_tool_picked_up(tool)

func _on_filing_area_interaction(area, tool_name):
	if level_manager.current_step == 1:
		if tool_name == "NailFile":
			_handle_file(area)
		elif tool_name == "NailCutter":
			_play_sfx(error_sound)
			update_instruction("Done cutting! Use the File.", "wrong")

func _start_filing_phase():
	level_manager.complete_step(0)
	_play_sfx(complete_sound)
	
	hand_cutting.visible = false
	hand_filing.visible = true
	
	# Filing Hand Entrance
	hand_filing.position.y = 800
	var entrance_tween = create_tween()
	entrance_tween.tween_property(hand_filing, "position:y", 496.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	current_cutting_frame = 0 # Reuse for filing steps
	
	for area in filing_areas:
		area.monitoring = true
		area.monitorable = true
	
	game_timer.stop()
	game_timer.wait_time = 20.0
	
	update_instruction("Great! Now use the Nail File to smooth the edges.")
	update_ui_text()
	
	# Highlight the file now
	add_glow_pulse(nail_file_sprite)

func _handle_file(area):
	var is_left = (area.name == "left")
	var made_progress = false
	
	if is_left:
		if hand_filing.frame == 0:
			hand_filing.frame = 1
			made_progress = true
			update_instruction("Nice! Now file the RIGHT side.", "correct")
	else:
		if hand_filing.frame == 1:
			hand_filing.frame = 2
			made_progress = true
			_release_active_tool()
			_finish_level()
		elif hand_filing.frame == 0:
			_play_sfx(error_sound)
			update_instruction("Start with the Left side!", "wrong")
			return

	if made_progress:
		_play_sfx(file_sound)
		GameManager.shake_camera(2.0, 0.05) # Add juice on file
		spawn_sparkles_at_shape_center(area)

func _finish_level():
	level_manager.complete_step(1)
	_play_sfx(victory_sound)
	game_timer.stop()
	timer_label.visible = false
	
	update_instruction("Amazing! All clean and smooth.", "correct")
	update_ui_text()
	
	show_completion_screen()

func show_completion_screen():
	# Scene-based completion screen (Matching Level 1)
	var completion_modal = $UI/CompletionModal
	if completion_modal:
		completion_modal.visible = true
		completion_modal.modulate.a = 0
		
		var panel = completion_modal.get_node_or_null("Panel")
		if panel:
			# Style logic similar to Level 1
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
			
		var continue_btn = completion_modal.find_child("ContinueButton", true, false)
		if continue_btn:
			GameManager.style_button(continue_btn, "green")
			if not continue_btn.pressed.is_connected(_on_continue_pressed):
				continue_btn.pressed.connect(_on_continue_pressed)

		var menu_btn = completion_modal.find_child("MainMenuButton", true, false)
		if menu_btn:
			GameManager.style_button(menu_btn, "blue")
			if not menu_btn.pressed.is_connected(_on_menu_pressed):
				menu_btn.pressed.connect(_on_menu_pressed)
				
		var tween_fade = create_tween()
		tween_fade.tween_property(completion_modal, "modulate:a", 1.0, 0.5)

func _on_continue_pressed():
	# Save and Exit
	GameManager.complete_level(1) # Level 2 is index 1
	get_tree().change_scene_to_file("res://Scenes/Level3.tscn")

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func play_tool_anim(anim_name):
	if nail_cutter_anim:
		nail_cutter_anim.play(anim_name)
		await nail_cutter_anim.animation_finished
		nail_cutter_anim.play("default")

func spawn_debris_at_shape_center(area):
	var pos = area.global_position
	for child in area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			pos += child.position * area.scale
			break
	spawn_debris(pos)

func spawn_sparkles_at_shape_center(area):
	var pos = area.global_position
	for child in area.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			pos += child.position * area.scale
			break
	if GameManager.has_method("spawn_sparkle"):
		GameManager.spawn_sparkle(pos)

func spawn_debris(pos):
	for i in range(3):
		var debris = CPUParticles2D.new()
		add_child(debris)
		var offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		debris.global_position = pos + offset
		debris.emitting = true
		debris.amount = 4
		debris.lifetime = 0.8
		debris.one_shot = true
		debris.explosiveness = 1.0
		debris.direction = Vector2(0, 1)
		debris.initial_velocity_min = 100
		debris.initial_velocity_max = 200
		debris.scale_amount_min = 3
		debris.scale_amount_max = 5
		debris.color = Color(0.95, 0.9, 0.8)
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(debris.queue_free)

func _play_sfx(stream):
	if sfx_player and stream:
		sfx_player.stream = stream
		sfx_player.play()

func update_ui_text():
	var tasks = ["Cut all nails", "File nails"]
	var text = "Tasks:\n"
	for i in range(tasks.size()):
		if i < level_manager.current_step:
			text += "[x] " + tasks[i] + "\n"
		elif i == level_manager.current_step:
			text += "[o] " + tasks[i] + "\n"
		else:
			text += "[ ] " + tasks[i] + "\n"
	checklist_label.text = text

func _on_step_completed(step):
	update_ui_text()
