extends CanvasLayer

signal finished_typing
signal dialogue_hidden

@onready var panel = $DialoguePanel
@onready var face_background = $background_face
@onready var rich_text = $DialoguePanel/RichTextLabel
@onready var face_animation = $background_face/AnimatedSprite2D

var is_typing: bool = false
var fade_tween: Tween
var text_tween: Tween
var auto_hide_tween: Tween

func _ready():
	panel.visible = false
	face_background.visible = false

func show_text(text: String, type: String = "talking", auto_hide_delay: float = 2.0):
	# Cancel any pending operations
	if fade_tween and fade_tween.is_valid(): fade_tween.kill()
	if text_tween and text_tween.is_valid(): text_tween.kill()
	if auto_hide_tween and auto_hide_tween.is_valid(): auto_hide_tween.kill()
	
	panel.visible = true
	face_background.visible = true
	# Ensure alpha is set if we were in the middle of fading out/in, or start fresh if hidden
	if panel.modulate.a == 0:
		panel.modulate.a = 0
		face_background.modulate.a = 0
	
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	fade_tween.tween_property(face_background, "modulate:a", 1.0, 0.3)
	
	# Set animation based on type
	if face_animation.sprite_frames.has_animation(type):
		face_animation.play(type)
	else:
		face_animation.play("talking")
	
	# Dynamic font scaling
	var base_font_size = 24
	var text_length = text.length()
	var new_font_size = base_font_size
	
	if text_length > 100:
		new_font_size = 18
	elif text_length > 80:
		new_font_size = 20
	elif text_length > 60:
		new_font_size = 22
		
	rich_text.add_theme_font_size_override("normal_font_size", new_font_size)
	
	rich_text.text = text
	rich_text.visible_characters = 0
	is_typing = true
	
	text_tween = create_tween()
	text_tween.tween_property(rich_text, "visible_ratio", 1.0, 1.0) # 1 second typing
	
	await text_tween.finished
	is_typing = false
	finished_typing.emit()
	
	# Transition face to talking if it was correct/wrong
	if type != "talking":
		await get_tree().create_timer(1.0).timeout
		if face_animation and face_animation.is_playing() and face_animation.animation == type:
			face_animation.play("talking")
	
	if auto_hide_delay > 0:
		# Use a tween for the delay so we can kill it easily
		auto_hide_tween = create_tween()
		auto_hide_tween.tween_interval(auto_hide_delay)
		await auto_hide_tween.finished
		hide_dialogue()

func hide_dialogue():
	if is_typing:
		# Force finish typing if hiding early
		if text_tween and text_tween.is_valid(): text_tween.kill()
		rich_text.visible_ratio = 1.0
		is_typing = false
		finished_typing.emit()
		
	if fade_tween and fade_tween.is_valid(): fade_tween.kill()
	if auto_hide_tween and auto_hide_tween.is_valid(): auto_hide_tween.kill()
	
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	fade_tween.tween_property(face_background, "modulate:a", 0.0, 0.3)
	
	await fade_tween.finished
	
	panel.visible = false
	face_background.visible = false
	dialogue_hidden.emit()
