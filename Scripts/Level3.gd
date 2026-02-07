extends Node2D

@onready var level_manager = $LevelManager
@onready var toothbrush = $Toothbrush
@onready var paste_visual = $Toothbrush/PasteVisual
@onready var checklist_label = $UI/ChecklistLabel

@onready var zone1 = $MouthOpen/Teeth/TeethZone1
@onready var zone2 = $MouthOpen/Teeth/TeethZone2

var is_brush_wet = false
var has_paste = false
var zones_cleaned = [false, false]


var brushing_progress = [0.0, 0.0]
var required_brushing_dist = 3000.0
var is_brushing_zone = -1
var last_mouse_pos = Vector2.ZERO

func _ready():
	level_manager.connect("step_completed", _on_step_completed)
	
	$Toothbrush/Bristles.connect("tool_dropped", _on_bristles_tool_dropped)
	
	connect_zone(zone1, 0)
	connect_zone(zone2, 1)
	
	update_ui_text()

func update_ui_text():
	var tasks = [
		"1. Wet toothbrush",
		"2. Apply toothpaste",
		"3. Brush teeth"
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

func _on_bristles_tool_dropped(tool_name):
	if tool_name == "Toothpaste" and level_manager.current_step == 1:
		has_paste = true
		paste_visual.visible = true
		level_manager.complete_step(1)
		print("Paste applied!")

func _on_cup_tool_dropped(tool_name):
	if tool_name == "Toothbrush" and level_manager.current_step == 0:
		is_brush_wet = true
		level_manager.complete_step(0)
		print("Brush wet!")

func connect_zone(zone_node, index):
	zone_node.connect("input_event", func(vp, ev, s_idx): _on_zone_input(index, vp, ev, s_idx))
	zone_node.connect("mouse_exited", func(): is_brushing_zone = -1)

func _on_zone_input(zone_index, _viewport, event, _shape_idx):
	if level_manager.current_step == 2:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_brushing_zone = zone_index
				last_mouse_pos = event.global_position
			else:
				is_brushing_zone = -1
		
		if event is InputEventMouseMotion and is_brushing_zone == zone_index:
			if not has_paste or not is_brush_wet:
				print("Prepare brush first!")
				return
				
			var dist = last_mouse_pos.distance_to(event.global_position)
			brushing_progress[zone_index] += dist
			last_mouse_pos = event.global_position
			

			var zone_node = [zone1, zone2][zone_index]
			var dirt = zone_node.get_node("Dirt")
			var progress_ratio = min(brushing_progress[zone_index] / required_brushing_dist, 1.0)
			dirt.modulate.a = 1.0 - progress_ratio
			
			if brushing_progress[zone_index] >= required_brushing_dist and not zones_cleaned[zone_index]:
				zones_cleaned[zone_index] = true
				GameManager.spawn_sparkle(zone_node.global_position)
				print("Zone ", zone_index, " cleaned!")
				check_brushing_completion()

func check_brushing_completion():
	var all_clean = true
	for c in zones_cleaned:
		if not c: all_clean = false
	
	if all_clean:
		level_manager.complete_step(2)
		GameManager.add_stars(3)
		print("All teeth cleaned! Level Complete.")

func _on_step_completed(step_index):
	update_ui_text()
