extends Area2D

# Base class for interactable tools

signal tool_used(tool_name)

@export var tool_name: String = "Tool"
@export var is_draggable: bool = true

@export var return_on_drop: bool = true
var dragging: bool = false
var original_position: Vector2

func _ready():
	original_position = global_position
	# Connect mouse signals for highlighting
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_pickable = true

func _on_mouse_entered():
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2), 0.1) # Brighten

func _on_mouse_exited():
	if not dragging:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)

func _input_event(_viewport, event, _shape_idx):
	if is_draggable and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				print("Picked up: ", tool_name)
			else:
				dragging = false
				print("Dropped: ", tool_name)
				check_drop_zone()
				if return_on_drop:
					return_to_start()

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position()

func check_drop_zone():
	var overlaps = get_overlapping_areas()
	for area in overlaps:
		if area.has_method("on_tool_dropped"):
			var handled = area.on_tool_dropped(self)
			if handled:
				emit_signal("tool_used", tool_name)
				return

func return_to_start():
	global_position = original_position
