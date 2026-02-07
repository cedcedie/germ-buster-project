extends Node2D

@onready var level_manager = $LevelManager
@onready var faucet = $Faucet
@onready var water_stream = $Faucet/WaterStream
@onready var soap = $Soap
@onready var hands = $Hands



var water_on: bool = false
var wetting_progress: float = 0.0
var rinsing_progress: float = 0.0
var progress_required: float = 2.0 # Seconds

@onready var checklist_label = $UI/ChecklistLabel

func _ready():
	level_manager.connect("step_completed", _on_step_completed)
	
	# Connect Faucet interaction
	faucet.connect("input_event", _on_faucet_input)
	
	# Connect Hands DropZone
	hands.connect("tool_dropped", _on_hands_tool_dropped)
	hands.connect("input_event", _on_hands_input)
	
	update_ui_text()

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

func _on_faucet_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if level_manager.current_step == 0:
			toggle_water(true)
			level_manager.complete_step(0)
		elif level_manager.current_step == 5:
			toggle_water(false)
			level_manager.complete_step(5)
			GameManager.add_stars(3)

func toggle_water(is_on: bool):
	water_on = is_on
	water_stream.visible = is_on

func _process(delta):
	# Handle continuous wetting/rinsing if mouse is held on hands and water is on
	if water_on and is_rubbing: # Reusing is_rubbing boolean for "is holding click"
		if level_manager.current_step == 1: # Wetting
			wetting_progress += delta
			print("Wetting: ", wetting_progress)
			if wetting_progress >= progress_required:
				level_manager.complete_step(1)
				print("Hands wet! Apply soap.")
				wetting_progress = 0
		elif level_manager.current_step == 4: # Rinsing
			rinsing_progress += delta
			print("Rinsing: ", rinsing_progress)
			if rinsing_progress >= progress_required:
				level_manager.complete_step(4)
				print("Hands rinsed! Turn off faucet.")
				rinsing_progress = 0

func _on_hands_tool_dropped(tool_name):
	if tool_name == "Soap" and level_manager.current_step == 2:
		level_manager.complete_step(2)
		print("Soap applied! Now rub hands.")

# Rubbing Mechanic Variables
var rubbing_progress: float = 0.0
var required_rubbing_dist: float = 5000.0
var is_rubbing: bool = false
var last_mouse_pos: Vector2

func _on_hands_input(_viewport, event, _shape_idx):
	# General click tracking for Wet/Rinse/Rub
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_rubbing = event.pressed # Reusing this var as "is_holding" for simplicity
			if is_rubbing:
				last_mouse_pos = event.global_position

	if level_manager.current_step == 3: # Rubbing Step
		if event is InputEventMouseMotion and is_rubbing:
			var dist = last_mouse_pos.distance_to(event.global_position)
			rubbing_progress += dist
			last_mouse_pos = event.global_position
			print("Rub progress: ", rubbing_progress)
			
			if rubbing_progress >= required_rubbing_dist:
				level_manager.complete_step(3)
				print("Rubbing complete! Rinse hands.")

func _on_step_completed(step_index):
	print("Completed step: ", step_index)
	update_ui_text()
