extends Node2D

@onready var level_manager = $LevelManager
@onready var nail1 = $Hand/Nail1
@onready var nail2 = $Hand/Nail2
@onready var nail3 = $Hand/Nail3
@onready var checklist_label = $UI/ChecklistLabel

var nail_states = [0, 0, 0]

var nails = []

func _ready():
	level_manager.connect("step_completed", _on_step_completed)
	
	nails = [nail1, nail2, nail3]
	for i in range(nails.size()):
		nails[i].connect("tool_dropped", func(tool_name): _on_nail_interaction(i, tool_name))
	
	update_ui_text()

func update_ui_text():
	var tasks = [
		"1. Cut all nails",
		"2. File all nails"
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

func _on_nail_interaction(nail_index, tool_name):
	var current_state = nail_states[nail_index]
	
	if level_manager.current_step == 0:
		if tool_name == "NailCutter" and current_state == 0:
			nail_states[nail_index] = 1
			update_nail_visual(nail_index)
			check_phase_completion()
		elif tool_name == "NailFile":
			print("Cut nails first!")
			
	elif level_manager.current_step == 1:
		if tool_name == "NailFile" and current_state == 1:
			nail_states[nail_index] = 2
			update_nail_visual(nail_index)
			check_phase_completion()

func update_nail_visual(index):
	var nail_sprite = nails[index].get_node("Sprite2D")
	GameManager.spawn_sparkle(nails[index].global_position) # Visual feedback
	if nail_states[index] == 1:
		nail_sprite.scale = Vector2(0.2, 0.15)
		print("Nail ", index, " cut.")
	elif nail_states[index] == 2:
		nail_sprite.modulate = Color(1, 1, 1, 1)
		print("Nail ", index, " filed.")

func check_phase_completion():
	var all_cut = true
	var all_filed = true
	
	for state in nail_states:
		if state < 1: all_cut = false
		if state < 2: all_filed = false
	
	if level_manager.current_step == 0 and all_cut:
		level_manager.complete_step(0)
		print("All nails cut! Now file them.")
		update_ui_text()
	elif level_manager.current_step == 1 and all_filed:
		level_manager.complete_step(1)
		GameManager.add_stars(3)
		print("All nails filed! Level Complete.")
		update_ui_text()

func _on_step_completed(step_index):
	update_ui_text()
