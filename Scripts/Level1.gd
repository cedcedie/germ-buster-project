extends Node2D

@onready var level_manager = $LevelManager
@onready var faucet_area = $Faucet
@onready var faucet_sprite = $Faucet/AnimatedSprite2D
@onready var faucet_water_sprite = $Faucet/AnimatedSprite2D2
@onready var two_hands = $TwoHands
@onready var hands_dropzone = $TwoHands/HandsDropZone
@onready var soap_area = $Soap
@onready var soap_sprite = $Soap/AnimatedSprite2D
@onready var toothbrush_area = $Toothbrush
@onready var soap_hands = $SoapHands
@onready var rubbing_hands = $RubbingHands
@onready var wet_hands_button = $UI/WetHandsButton
@onready var rub_hands_button = $UI/RubHandsButton
@onready var rinse_hands_button = $UI/RinseHandsButton
@onready var dialogue_box = $UI/DialogueBox
@onready var timer_label = $UI/TimerLabel
@onready var game_timer = $GameTimer
@onready var completion_modal = $UI/CompletionModal
@onready var continue_button = $UI/CompletionModal/Panel/VBoxContainer/ContinueButton

# Audio players
@onready var faucet_loop = $AudioPlayers/FaucetLoop
@onready var sfx_player = $AudioPlayers/SFXPlayer
@onready var music_player = $AudioPlayers/MusicPlayer

var current_step: int = 0
var faucet_is_on: bool = false
var is_dragging_soap: bool = false
var is_dragging_toothbrush: bool = false
var soap_offset: Vector2 = Vector2.ZERO
var toothbrush_offset: Vector2 = Vector2.ZERO

# Audio streams - will be loaded in _ready
var faucet_sound: AudioStream
var button_click_sound: AudioStream
var wrong_item_sound: AudioStream
var step_complete_sound: AudioStream
var level_complete_sound: AudioStream
var level_music: AudioStream

@onready var checklist_label = $UI/ChecklistLabel

func _ready():
	# Load audio files
	faucet_sound = load("res://Assets/Audio/SFX/faucet.mp3")
	button_click_sound = load("res://Assets/Audio/SFX/button_click.mp3")
	wrong_item_sound = load("res://Assets/Audio/SFX/wrong_item.mp3")
	step_complete_sound = load("res://Assets/Audio/SFX/step_complete.mp3")
	level_complete_sound = load("res://Assets/Audio/SFX/level_complete.mp3")
	level_music = load("res://Assets/Audio/Music/level1_music.ogg")
	
	# Setup audio players
	music_player.stream = level_music
	music_player.volume_db = -10
	music_player.play()
	
	faucet_loop.stream = faucet_sound
	faucet_loop.volume_db = -5
	
	level_manager.connect("step_completed", _on_step_completed)
	
	# Connect Faucet Area2D input
	faucet_area.connect("input_event", _on_faucet_clicked)
	
	# Connect buttons with hover effects
	setup_button_animations(wet_hands_button)
	setup_button_animations(rub_hands_button)
	setup_button_animations(rinse_hands_button)
	
	GameManager.style_button(wet_hands_button, "blue")
	GameManager.style_button(rub_hands_button, "yellow")
	GameManager.style_button(rinse_hands_button, "green")
	GameManager.style_button(continue_button, "green")
	
	wet_hands_button.connect("pressed", _on_wet_hands_button_pressed)
	rub_hands_button.connect("pressed", _on_rub_hands_button_pressed)
	rinse_hands_button.connect("pressed", _on_rinse_hands_button_pressed)
	continue_button.connect("pressed", _on_continue_button_pressed)
	
	# Connect Soap drag and drop
	soap_area.connect("input_event", _on_soap_input_event)
	hands_dropzone.connect("area_entered", _on_item_dropped_on_hands)
	
	# Connect Toothbrush drag and drop
	toothbrush_area.connect("input_event", _on_toothbrush_input_event)
	
	# Hide water animation initially
	faucet_water_sprite.visible = false
	faucet_water_sprite.modulate.a = 0
	
	# Set initial alpha for fade animations
	two_hands.modulate.a = 1
	soap_hands.modulate.a = 0
	rubbing_hands.modulate.a = 0
	
	# Force apply universal font to critical UI elements
	var game_font = load("res://Daily Vibes.otf")
	if game_font:
		checklist_label.add_theme_font_override("font", game_font)
		timer_label.add_theme_font_override("font", game_font)
		wet_hands_button.add_theme_font_override("font", game_font)
		rub_hands_button.add_theme_font_override("font", game_font)
		rinse_hands_button.add_theme_font_override("font", game_font)
	
	# Don't connect timeout for generic failure anymore per request
	# game_timer.timeout.connect(_on_timer_timeout) 
	
	# Initial instruction
	timer_label.visible = false 
	update_instruction_animated("Hi there! Our hands are a bit dirty. Can you help me turn on the water? Just click the faucet!")
	
	_add_germ_details()
	update_ui_text()
	
	# Start glowing the first target
	add_glow_pulse(faucet_sprite)
	# Transition Fade In (from black)
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 100 # Top
	add_child(fade_layer)
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
	fade_tween.finished.connect(fade_layer.queue_free)

var germ_particles: Array[CPUParticles2D] = []

func _add_germ_details():
	var hands_to_infect = [two_hands, soap_hands, rubbing_hands]
	for hand in hands_to_infect:
		if not hand: continue
		var germs = GameManager.spawn_germ_particles(hand, Vector2(320, 240), 30, Vector2(8, 15))
		germ_particles.append(germs)

func _clear_germs():
	for germs in germ_particles:
		var tween = create_tween()
		tween.tween_property(germs, "modulate:a", 0.0, 1.0)
		tween.finished.connect(germs.queue_free)
	germ_particles.clear()

# ===== ANIMATION HELPER FUNCTIONS =====

func setup_button_animations(button: Button):
	button.mouse_entered.connect(func(): animate_button_hover(button, true))
	button.mouse_exited.connect(func(): animate_button_hover(button, false))

func animate_button_hover(button: Button, is_hovering: bool):
	# User requested "simple button" - removing bouncy scaling
	# Just slight modulate or nothing (Godot default hover is usually color tint if themed)
	var target_modulate = Color(0.8, 0.8, 0.8) if is_hovering else Color(1, 1, 1)
	var tween = create_tween()
	tween.tween_property(button, "modulate", target_modulate, 0.1)

func fade_out_button(button: Button):
	play_sfx(button_click_sound)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(button, "modulate:a", 0.0, 0.3)
	tween.tween_property(button, "scale", Vector2(0.8, 0.8), 0.3)

func fade_in_sprite(sprite: Node2D, duration: float = 0.5):
	sprite.visible = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, duration)

func fade_out_sprite(sprite: Node2D, duration: float = 0.5):
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, duration)
	await tween.finished
	sprite.visible = false

func fade_in_control(control: Control, duration: float = 0.5):
	control.visible = true
	var tween = create_tween()
	tween.tween_property(control, "modulate:a", 1.0, duration)

func crossfade_sprites(fade_out: Node2D, fade_in: Node2D, duration: float = 0.5):
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_out, "modulate:a", 0.0, duration)
	fade_in.visible = true
	fade_in.modulate.a = 0
	tween.tween_property(fade_in, "modulate:a", 1.0, duration)
	await tween.finished
	fade_out.visible = false

func shake_sprite(sprite: Node2D, strength: float = 10.0, duration: float = 0.5):
	var original_pos = sprite.position
	var tween = create_tween()
	for i in range(8):
		var offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(sprite, "position", original_pos + offset, duration / 16.0)
	tween.tween_property(sprite, "position", original_pos, duration / 16.0)

func update_instruction_animated(text: String, type: String = "talking"):
	# Safeguard: Always stop the timer the moment a dialogue starts
	game_timer.stop()
	
	# Hide timer during dialogue to avoid confusion
	timer_label.visible = false
	
	# Reset timer internal state - removing default 10s reset
	# timer_label.text = "Time: 10s"
	# game_timer.wait_time = 10.0
	
	# Show text and auto-hide after 3 seconds
	dialogue_box.show_text(text, type, 3.0)
	
	
	# Wait for the dialogue to completely disappear before starting the timer
	if not dialogue_box.dialogue_hidden.is_connected(resume_timer_after_dialogue):
		dialogue_box.dialogue_hidden.connect(resume_timer_after_dialogue, CONNECT_ONE_SHOT)

func resume_timer_after_dialogue():
	# Timer only starts specifically for certain tasks now
	pass

func _on_timer_timeout():
	# Timer only used for rubbing phase now, so this generic timeout isn't really used for failure anymore.
	pass

# ===== AUDIO HELPER FUNCTIONS =====

func play_sfx(sound: AudioStream):
	sfx_player.stream = sound
	sfx_player.play()

func start_faucet_loop():
	if not faucet_loop.playing:
		faucet_loop.play()

func stop_faucet_loop():
	var tween = create_tween()
	tween.tween_property(faucet_loop, "volume_db", -80, 0.5)
	await tween.finished
	faucet_loop.stop()
	faucet_loop.volume_db = -5

# ===== VISUAL HELPERS =====
var active_glow_tween: Tween

func add_glow_pulse(node: CanvasItem):
	# Stop any existing glow first
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
	# Reset modulations of potential targets just in case
	faucet_sprite.modulate = Color(1,1,1)
	wet_hands_button.modulate = Color(1,1,1)
	soap_area.modulate = Color(1,1,1)
	rub_hands_button.modulate = Color(1,1,1)
	rinse_hands_button.modulate = Color(1,1,1)

# ===== GAME LOGIC =====

func update_ui_text():
	var tasks = [
		"1. Turn on faucet",
		"2. Wet hands",
		"3. Apply soap",
		"4. Rub hands",
		"5. Rinse hands",
		"6. Turn off faucet"
	]
	var text = "Tasks:\n"
	for i in range(tasks.size()):
		if i < level_manager.current_step:
			text += "[x] " + tasks[i] + "\n"
		elif i == level_manager.current_step:
			text += "[o] " + tasks[i] + "\n"
		else:
			text += "[ ] " + tasks[i] + "\n"
	checklist_label.text = text

func update_instruction(text: String):
	dialogue_box.show_text(text)

# ===== PHASE 1: TURN ON FAUCET =====

func _on_faucet_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Step 1: Turn on faucet
		if level_manager.current_step == 0 and not faucet_is_on:
			faucet_is_on = true
			faucet_sprite.visible = false
			faucet_water_sprite.visible = true
			fade_in_sprite(faucet_water_sprite, 0.3)
			faucet_water_sprite.play("faucet_impact")
			start_faucet_loop()
			play_sfx(button_click_sound)
			
			# Visual pop effect
			var pop_tween = create_tween()
			pop_tween.tween_property(faucet_sprite, "scale", Vector2(1.2, 1.2), 0.1)
			pop_tween.tween_property(faucet_sprite, "scale", Vector2(1.0, 1.0), 0.1)
			
			remove_glow_pulse() # Stop glowing faucet
			
			level_manager.complete_step(0)
			GameManager.shake_camera(2.0, 0.1)
			print("Faucet turned on!")
		# Step 6: Turn off faucet
		elif level_manager.current_step == 5 and faucet_is_on:
			faucet_is_on = false
			await fade_out_sprite(faucet_water_sprite, 0.3)
			faucet_sprite.visible = true
			faucet_sprite.play("faucet_off")
			stop_faucet_loop()
			play_sfx(button_click_sound)
			
			# Visual pop effect
			var pop_tween = create_tween()
			pop_tween.tween_property(faucet_sprite, "scale", Vector2(1.2, 1.2), 0.1)
			pop_tween.tween_property(faucet_sprite, "scale", Vector2(1.0, 1.0), 0.1)
			
			level_manager.complete_step(5)
			print("Faucet turned off!")
			# Show completion modal
			show_completion_modal()

# ===== PHASE 2: WET HANDS =====

func _on_wet_hands_button_pressed():
	if level_manager.current_step == 1:
		remove_glow_pulse() # Stop button glow
		fade_out_button(wet_hands_button)
		await get_tree().create_timer(0.3).timeout
		wet_hands_button.visible = false
		animate_hands_up()

func animate_hands_up():
	update_instruction_animated("Moving hands to faucet...")
	two_hands.modulate.a = 0
	two_hands.visible = true
	
	game_timer.stop() # Stop timer for movement animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(two_hands, "position", Vector2(584, 496), 1.5)
	tween.tween_property(two_hands, "modulate:a", 1.0, 1.0)
	await tween.finished
	
	level_manager.complete_step(1)
	# game_timer.start() # Removed generic timer
	print("Hands are wet!")

# ===== PHASE 3: SOAP DRAG AND DROP =====

func _on_soap_input_event(_viewport, event, _shape_idx):
	if level_manager.current_step != 2:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging_soap = true
				soap_offset = soap_area.global_position - event.global_position
				# Scale up when dragging
				var tween = create_tween()
				tween.tween_property(soap_area, "scale", Vector2(1.9, 1.9), 0.2)
				remove_glow_pulse() # Stop glowing once they grab it
				print("Started dragging soap")
			else:
				is_dragging_soap = false
				# Scale back
				var tween = create_tween()
				tween.tween_property(soap_area, "scale", Vector2(1.7, 1.7), 0.2)
				print("Stopped dragging soap")

func _on_toothbrush_input_event(_viewport, event, _shape_idx):
	if level_manager.current_step != 2:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging_toothbrush = true
				toothbrush_offset = toothbrush_area.global_position - event.global_position
				# Scale up when dragging
				var tween = create_tween()
				tween.tween_property(toothbrush_area, "scale", Vector2(1.5, 1.5), 0.2)
				print("Started dragging toothbrush")
			else:
				is_dragging_toothbrush = false
				# Scale back
				var tween = create_tween()
				tween.tween_property(toothbrush_area, "scale", Vector2(1.3, 1.3), 0.2)
				print("Stopped dragging toothbrush")

func _process(delta):
	if is_dragging_soap:
		soap_area.global_position = get_global_mouse_position() + soap_offset
	if is_dragging_toothbrush:
		toothbrush_area.global_position = get_global_mouse_position() + toothbrush_offset
		
	# Update timer display only if active
	if timer_label.visible and game_timer.time_left > 0:
		timer_label.text = "Time: %ds" % int(ceil(game_timer.time_left))
	elif timer_label.visible:
		timer_label.text = "Time's Up!"

func _on_item_dropped_on_hands(area: Area2D):
	if level_manager.current_step != 2:
		return
		
	# Check if toothbrush was dropped
	if area == toothbrush_area and is_dragging_toothbrush:
		is_dragging_toothbrush = false
		play_sfx(wrong_item_sound)
		shake_sprite(toothbrush_area, 15.0, 0.5)
		update_instruction_animated("Oopsie! That's a toothbrush. We use that for our teeth, but right now we need SOAP for our hands!", "wrong")
		print("Wrong item - toothbrush!")
		# Reset toothbrush position
		await get_tree().create_timer(2.5).timeout
		var tween = create_tween()
		tween.tween_property(toothbrush_area, "position", Vector2(112, 400), 0.5)
		await tween.finished
		if level_manager.current_step == 2:
			update_instruction_animated("Can you find the soap and drag it to your hands?", "talking")
		return
	
	# Check if soap was dropped
	if area == soap_area and is_dragging_soap:
		is_dragging_soap = false
		print("Soap applied to hands!")
		update_instruction_animated("Applying soap...")
		
		# Visual pop effect for soap
		var pop_tween = create_tween()
		pop_tween.tween_property(soap_area, "scale", Vector2(2.2, 2.2), 0.1)
		pop_tween.tween_property(soap_area, "scale", Vector2(1.7, 1.7), 0.1)
		
		# Play soap apply animation on the soap sprite
		soap_sprite.play("soap_apply")
		
		game_timer.stop() # Stop for soap application animation
		# Wait 5 seconds for soap animation
		await get_tree().create_timer(5.0).timeout
		
		# Now crossfade to soap hands
		soap_hands.position = Vector2(584, 496)
		await crossfade_sprites(two_hands, soap_hands, 0.5)
		soap_area.visible = false
		
		# Complete step 3
		level_manager.complete_step(2)
		GameManager.shake_camera(5.0, 0.2) # Added juice
		# game_timer.start() # Removed generic timer
		print("Soap application complete!")

# ===== PHASE 4: RUB HANDS =====

func _on_rub_hands_button_pressed():
	if level_manager.current_step == 3:
		remove_glow_pulse()
		fade_out_button(rub_hands_button)
		await get_tree().create_timer(0.3).timeout
		rub_hands_button.visible = false
		animate_rubbing_hands()

func animate_rubbing_hands():
	update_instruction_animated("Keep rubbing for 30 seconds! Every bubble counts.")
	
	# Start 30s timer
	game_timer.wait_time = 30.0
	game_timer.start()
	timer_label.visible = true
	
	# Crossfade to rubbing animation
	rubbing_hands.position = Vector2(584, 496)
	await crossfade_sprites(soap_hands, rubbing_hands, 0.5)
	rubbing_hands.play("rub_hands")
	
	# Loop until timer finishes
	while game_timer.time_left > 0:
		timer_label.text = "Time: %ds" % int(ceil(game_timer.time_left))
		await get_tree().process_frame
	
	timer_label.visible = false
	
	# Crossfade back to soap hands
	await crossfade_sprites(rubbing_hands, soap_hands, 0.5)
	
	_clear_germs()
	
	# Complete step 4
	level_manager.complete_step(3)
	GameManager.shake_camera(5.0, 0.2) # Added juice
	print("Hands rubbed thoroughly for 30 seconds!")

# ===== PHASE 5: RINSE HANDS =====

func _on_rinse_hands_button_pressed():
	if level_manager.current_step == 4:
		remove_glow_pulse()
		fade_out_button(rinse_hands_button)
		await get_tree().create_timer(0.3).timeout
		rinse_hands_button.visible = false
		animate_rinsing_hands()

func animate_rinsing_hands():
	update_instruction_animated("Moving hands to faucet...")
	
	game_timer.stop() # Stop for rinsing/movement animation
	# Move soap hands up to faucet
	var tween1 = create_tween()
	tween1.set_ease(Tween.EASE_IN_OUT)
	tween1.set_trans(Tween.TRANS_QUAD)
	tween1.tween_property(soap_hands, "position", Vector2(584, 352), 1.0)
	await tween1.finished
	
	# Crossfade to rubbing hands for rinsing animation
	rubbing_hands.position = Vector2(584, 352)
	await crossfade_sprites(soap_hands, rubbing_hands, 0.5)
	rubbing_hands.play("rub_hands")
	update_instruction_animated("Rinsing hands...")
	
	# Wait 5 seconds for rinsing animation
	await get_tree().create_timer(5.0).timeout
	
	# Crossfade to clean two hands
	two_hands.position = Vector2(584, 352)
	two_hands.modulate.a = 0
	await crossfade_sprites(rubbing_hands, two_hands, 0.5)
	
	# Move two hands back down to 486
	var tween2 = create_tween()
	tween2.set_ease(Tween.EASE_IN_OUT)
	tween2.set_trans(Tween.TRANS_QUAD)
	tween2.tween_property(two_hands, "position", Vector2(584, 486), 1.0)
	await tween2.finished
	
	# Complete step 5
	level_manager.complete_step(4)
	# game_timer.start() # Removed generic timer
	print("Hands rinsed!")

# ===== PHASE 6: COMPLETION =====

func show_completion_modal():
	# Stop any currently playing SFX first
	sfx_player.stop()
	
	# Play completion sound at lower volume
	sfx_player.stream = level_complete_sound
	sfx_player.volume_db = -10
	sfx_player.play()
	
	# Spawn fancy sparkles
	for i in range(10):
		GameManager.spawn_sparkle(Vector2(randf_range(200, 1000), randf_range(100, 500)))
		await get_tree().create_timer(0.05).timeout
	
	completion_modal.modulate.a = 0
	completion_modal.visible = true
	
	var panel = completion_modal.get_node("Panel")
	# Stylize Panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.3, 0.4, 0.95)
	style.set_corner_radius_all(20)
	style.shadow_size = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	
	panel.position.y = -300
	
	# Setup Buttons
	var vbox = panel.get_node("VBoxContainer")
	var continue_btn = vbox.get_node("ContinueButton")
	
	# Update Continue Button
	continue_btn.text = "Continue to Level 2"
	if continue_btn.is_connected("pressed", _on_continue_button_pressed):
		continue_btn.disconnect("pressed", _on_continue_button_pressed)
	continue_btn.pressed.connect(_on_continue_to_level_2)
	setup_button_animations(continue_btn)
	
	# Add Menu Button if not exists
	var menu_btn = vbox.get_node_or_null("MenuButton")
	if not menu_btn:
		menu_btn = Button.new()
		menu_btn.name = "MenuButton"
		menu_btn.text = "Main Menu"
		menu_btn.add_theme_font_size_override("font_size", 20)
		vbox.add_child(menu_btn)
		vbox.move_child(menu_btn, vbox.get_child_count() - 2)
		menu_btn.pressed.connect(_on_menu_button_pressed)
		GameManager.style_button(menu_btn, "blue")
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(completion_modal, "modulate:a", 1.0, 0.5)
	tween.tween_property(panel, "position:y", 0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Wait for the sound to finish playing before resetting volume
	await sfx_player.finished
	sfx_player.volume_db = 0

func _on_continue_to_level_2():
	play_sfx(button_click_sound)
	# Save progress before moving
	GameManager.complete_level(0) 
	
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Scenes/Level2.tscn")

func _on_menu_button_pressed():
	play_sfx(button_click_sound)
	# Also save progress if they choose to go to menu
	GameManager.complete_level(0)
	
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_continue_button_pressed():
	# Deprecated, redirected to _on_continue_to_level_2
	_on_continue_to_level_2()

func _on_step_completed(step_index):
	print("Completed step: ", step_index)
	
	# Only play step complete sound for steps 0-4, not the final step
	if step_index < 5:
		play_sfx(step_complete_sound)
	
	update_ui_text()
	
	# Step-specific actions and notifications
	match step_index:
		0: # Faucet turned on
			wet_hands_button.visible = true
			wet_hands_button.modulate.a = 0
			fade_in_control(wet_hands_button, 0.5)
			add_glow_pulse(wet_hands_button)
			update_instruction_animated("Great job! Running water helps wash away loose dirt. Let's get our hands wet! Click 'Wet Hands'.", "correct")
		1: # Hands wet
			soap_area.visible = true
			add_glow_pulse(soap_area)
			update_instruction_animated("Nice! Wetting your hands first helps the soap create lots of bubbles to trap germs. Now, drag the soap to your hands!", "correct")
		2: # Soap applied
			rub_hands_button.visible = true
			rub_hands_button.modulate.a = 0
			fade_in_control(rub_hands_button, 0.5)
			add_glow_pulse(rub_hands_button)
			update_instruction_animated("Perfect! Soap breaks down the oils that germs hide in. Let's rub them all around! Click 'Rub Hands'.", "correct")
		3: # Hands rubbed
			rinse_hands_button.visible = true
			rinse_hands_button.modulate.a = 0
			fade_in_control(rinse_hands_button, 0.5)
			add_glow_pulse(rinse_hands_button)
			update_instruction_animated("Wow! Rubbing for 20 seconds makes sure we catch all the sneaky germs. Now, let's rinse them away! Click 'Rinse Hands'.", "correct")
		4: # Hands rinsed
			add_glow_pulse(faucet_sprite)
			update_instruction_animated("All clean! Rinsing washes the soap and trapped germs right down the drain. Let's save water and turn off the faucet!", "correct")
		5: # Level complete
			game_timer.stop()
			update_instruction_animated("Level Complete! You're a Germ Buster Master! Clean hands keep you healthy!", "correct")
