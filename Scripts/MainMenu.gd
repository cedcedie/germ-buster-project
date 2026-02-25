extends Control

@onready var music_player = $AudioPlayers/MusicPlayer
@onready var sfx_player = $AudioPlayers/SFXPlayer
@onready var start_button = $CenterContainer/VBoxContainer/ButtonsContainer/StartButton
@onready var quit_button = $CenterContainer/VBoxContainer/ButtonsContainer/QuitButton

var button_click_sound: AudioStream
var menu_music: AudioStream

func _ready():
	# Load audio
	button_click_sound = load("res://Assets/Audio/SFX/button_click.mp3")
	menu_music = load("res://Assets/Audio/Music/menu_music.ogg")
	
	# Setup music
	music_player.stream = menu_music
	music_player.volume_db = -8
	music_player.play()
	
	# Animate menu entrance
	animate_menu_entrance()
	
	# Add background germ juice
	_setup_background_germs()
	
	# Apply font centralization
	GameManager.apply_font_to_ui(self)
	
	# Check for Save Game -> Add Continue Button
	if GameManager.max_unlocked_level > 0:
		_setup_continue_button()
	
	# Apply premium styles
	_apply_premium_button_styles()
	_start_title_animation()

func _setup_continue_button():
	var buttons_container = $CenterContainer/VBoxContainer/ButtonsContainer
	
	# Create Button
	var continue_btn = Button.new()
	var display_level = GameManager.last_played_level + 1
	var button_text = "Continue (Level " + str(display_level) + ")"
	
	if GameManager.max_unlocked_level >= GameManager.levels.size():
		button_text = "Replay (Level " + str(GameManager.levels.size()) + ")"
		
	continue_btn.text = button_text
	continue_btn.name = "ContinueButton"
	# Add styling if possible, or reliance on theme
	
	# Add as first child
	buttons_container.add_child(continue_btn)
	buttons_container.move_child(continue_btn, 0)
	
	continue_btn.pressed.connect(_on_ContinueButton_pressed)
	
	# Add hover animation
	continue_btn.mouse_entered.connect(func(): _on_button_hover(continue_btn, true))
	continue_btn.mouse_exited.connect(func(): _on_button_hover(continue_btn, false))

func _on_ContinueButton_pressed():
	play_button_click()
	
	# Fade out animation (Fade to Black)
	var overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	tween.tween_property(music_player, "volume_db", -80, 0.5)
	
	await tween.finished
	_cleanup_menu_germs()
	GameManager.continue_game()
func _cleanup_menu_germs():
	for child in get_children():
		if child is CanvasLayer and child.layer == -1:
			child.queue_free()

func animate_menu_entrance():
	var title_section = $CenterContainer/VBoxContainer/TitleSection
	var buttons_container = $CenterContainer/VBoxContainer/ButtonsContainer
	var info_panel = $CenterContainer/VBoxContainer/InfoPanel
	
	# Start with everything invisible
	title_section.modulate.a = 0
	buttons_container.modulate.a = 0
	info_panel.modulate.a = 0
	
	# Fade in sequence
	var tween = create_tween()
	tween.tween_property(title_section, "modulate:a", 1.0, 0.5)
	tween.tween_property(buttons_container, "modulate:a", 1.0, 0.5)
	tween.tween_property(info_panel, "modulate:a", 1.0, 0.5)

func _on_button_hover(button: Button, is_hovering: bool):
	# Enhanced hover effect (Scaling and Color)
	var tween = create_tween()
	tween.set_parallel(true)
	if is_hovering:
		tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1)
		tween.tween_property(button, "modulate", Color(0.9, 0.9, 1.1), 0.1) # Slight blue tint
	else:
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(button, "modulate", Color(1, 1, 1), 0.1)

func _setup_background_germs():
	# Use centralized particle system for background decoration
	var germ_layer = CanvasLayer.new()
	germ_layer.layer = -1 # Behind everything
	add_child(germ_layer)
	
	for i in range(5):
		var pos = Vector2(randf_range(100, 1100), randf_range(100, 600))
		var marker = Marker2D.new()
		marker.position = pos
		germ_layer.add_child(marker)
		GameManager.spawn_germ_particles(marker, Vector2(50, 50), 5, Vector2(10, 20))
func _on_StartButton_pressed():
	play_button_click()
	
	# Fade out animation (Fade to Black)
	var overlay = ColorRect.new()
	overlay.color = Color.BLACK
	overlay.modulate.a = 0
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(overlay, "modulate:a", 1.0, 0.5)
	tween.tween_property(music_player, "volume_db", -80, 0.5)
	
	await tween.finished
	_cleanup_menu_germs()
	GameManager.start_game()

func _on_QuitButton_pressed():
	play_button_click()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func play_button_click():
	sfx_player.stream = button_click_sound
	sfx_player.play()

func _apply_premium_button_styles():
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.55, 0.9, 1.0) # Vibrant Blue
	normal_style.set_corner_radius_all(20)
	normal_style.shadow_size = 5
	normal_style.shadow_color = Color(0, 0, 0, 0.3)
	normal_style.border_width_bottom = 5
	normal_style.border_color = Color(0.1, 0.4, 0.7, 1.0) # Darker blue border for 3D effect

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.65, 1.0, 1.0) # Brighter blue
	hover_style.border_color = Color(0.15, 0.5, 0.8, 1.0)

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.45, 0.75, 1.0)
	pressed_style.border_width_bottom = 2 # Compressed look

	var buttons = [start_button, quit_button]
	
	# Find continue button if it exists
	var continue_btn = $CenterContainer/VBoxContainer/ButtonsContainer.get_node_or_null("ContinueButton")
	if continue_btn: buttons.append(continue_btn)

	for btn in buttons:
		if not btn: continue
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", pressed_style)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new()) # Remove focus ring
		btn.pivot_offset = btn.size / 2 # Ensure scale center is correct

	# Style the Quit button differently (Reddish)
	var quit_normal = normal_style.duplicate()
	quit_normal.bg_color = Color(0.8, 0.3, 0.3, 1.0)
	quit_normal.border_color = Color(0.6, 0.2, 0.2, 1.0)
	
	var quit_hover = hover_style.duplicate()
	quit_hover.bg_color = Color(0.9, 0.4, 0.4, 1.0)
	quit_hover.border_color = Color(0.7, 0.3, 0.3, 1.0)
	
	quit_button.add_theme_stylebox_override("normal", quit_normal)
	quit_button.add_theme_stylebox_override("hover", quit_hover)

func _start_title_animation():
	var title = $CenterContainer/VBoxContainer/TitleSection/TitleLabel
	if not title: return
	
	title.pivot_offset = title.size / 2
	var tween = create_tween().set_loops()
	tween.tween_property(title, "scale", Vector2(1.05, 1.05), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(title, "scale", Vector2(1.0, 1.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var subtitle = $CenterContainer/VBoxContainer/TitleSection/SubtitleLabel
	if not subtitle: return
	var sub_tween = create_tween().set_loops()
	sub_tween.tween_property(subtitle, "modulate:a", 0.6, 2.0).set_trans(Tween.TRANS_SINE)
	sub_tween.tween_property(subtitle, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)
