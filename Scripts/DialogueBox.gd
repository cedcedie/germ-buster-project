extends CanvasLayer

signal finished_typing
signal dialogue_hidden

@onready var panel = $DialoguePanel
@onready var face_background = $background_face
@onready var rich_text = $DialoguePanel/RichTextLabel
@onready var face_animation = $background_face/AnimatedSprite2D

var is_typing: bool = false

func _ready():
	panel.visible = false
	face_background.visible = false

func show_text(text: String, type: String = "talking", auto_hide_delay: float = 2.0):
	panel.visible = true
	face_background.visible = true
	panel.modulate.a = 0
	face_background.modulate.a = 0
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(face_background, "modulate:a", 1.0, 0.3)
	
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
	
	var text_tween = create_tween()
	text_tween.tween_property(rich_text, "visible_ratio", 1.0, 1.0) # 1 second typing
	await text_tween.finished
	
	is_typing = false
	finished_typing.emit()
	
	# Transition face to talking if it was correct/wrong
	if type != "talking":
		await get_tree().create_timer(1.0).timeout
		face_animation.play("talking")
	
	if auto_hide_delay > 0:
		await get_tree().create_timer(auto_hide_delay).timeout
		await hide_dialogue()

func hide_dialogue():
	if is_typing:
		await finished_typing
		
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.tween_property(face_background, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	panel.visible = false
	face_background.visible = false
	dialogue_hidden.emit()
