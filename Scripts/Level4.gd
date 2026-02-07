extends Node2D

@onready var level_manager = $LevelManager
@onready var dispenser = $FlossDispenser
@onready var floss_piece = $FlossPiece
@onready var gap1 = $MouthOpen/Teeth/Gap1
@onready var gap2 = $MouthOpen/Teeth/Gap2
@onready var checklist_label = $UI/ChecklistLabel

var floss_cut = false
var gaps_cleaned = [false, false]

var flossing_progress = [0.0, 0.0]
var required_floss_dist = 2000.0
var active_gap = -1
var last_mouse_pos = Vector2.ZERO

func _ready():
	level_manager.connect("step_completed", _on_step_completed)
	
	$FlossDispenser.connect("input_event", _on_dispenser_input)
	
	connect_gap(gap1, 0)
	connect_gap(gap2, 1)
	
	update_ui_text()

func update_ui_text():
	var tasks = [
		"1. Cut floss",
		"2. Floss all gaps"
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

func _on_dispenser_input(_viewport, event, _shape_idx):
	if level_manager.current_step == 0:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if not floss_cut:
				floss_cut = true
				floss_piece.visible = true
				floss_piece.position = dispenser.position + Vector2(50, 0)
				level_manager.complete_step(0)
				print("Floss cut!")

func connect_gap(gap_node, index):
	gap_node.connect("input_event", func(vp, ev, s_idx): _on_gap_input(index, vp, ev, s_idx))
	gap_node.connect("mouse_exited", func(): active_gap = -1)

func _on_gap_input(gap_index, _viewport, event, _shape_idx):
	if level_manager.current_step == 1:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				active_gap = gap_index
				last_mouse_pos = event.global_position
			else:
				active_gap = -1
		
		if event is InputEventMouseMotion and active_gap == gap_index:
			var dist = abs(event.relative.y)
			flossing_progress[gap_index] += dist
			
			var gap_node = [gap1, gap2][gap_index]
			var dirt = gap_node.get_node("Dirt")
			var progress_ratio = min(flossing_progress[gap_index] / required_floss_dist, 1.0)
			dirt.modulate.a = 1.0 - progress_ratio
			
			if flossing_progress[gap_index] >= required_floss_dist and not gaps_cleaned[gap_index]:
				gaps_cleaned[gap_index] = true
				GameManager.spawn_sparkle(gap_node.global_position)
				print("Gap ", gap_index, " cleaned!")
				check_flossing_completion()

func check_flossing_completion():
	var all_clean = true
	for c in gaps_cleaned:
		if not c: all_clean = false
	
	if all_clean:
		level_manager.complete_step(1)
		GameManager.add_stars(3)
		print("All gaps cleaned! Level Complete.")
		GameManager.next_level() 

func _on_step_completed(step_index):
	update_ui_text()
