extends Area2D

# Base class for interactable tools

signal tool_used(tool_name)

@export var tool_name: String = "Tool"
@export var is_draggable: bool = true

var dragging: bool = false
var original_position: Vector2

func _ready():
	original_position = global_position

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
				return_to_start()

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position()

func check_drop_zone():
	var overlaps = get_overlapping_areas()
	for area in overlaps:
		if area.has_method("on_tool_dropped"):
			area.on_tool_dropped(self)
			emit_signal("tool_used", tool_name)
			return

func return_to_start():
	global_position = original_position
