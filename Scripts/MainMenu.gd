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
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	if is_hovering:
		tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.2)
	else:
		tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.2)

func _on_StartButton_pressed():
	play_button_click()
	
	# Fade out animation
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_property(music_player, "volume_db", -80, 0.5)
	
	await tween.finished
	GameManager.start_game()

func _on_QuitButton_pressed():
	play_button_click()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func play_button_click():
	sfx_player.stream = button_click_sound
	sfx_player.play()
