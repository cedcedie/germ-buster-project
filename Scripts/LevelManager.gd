extends Node

# Manages logic for a specific level

signal step_completed(step_index)
signal level_completed

@export var total_steps: int = 0
@export var level_name: String = ""

var current_step: int = 0
var completed_steps: Array[bool] = []

func _ready():
	# Initialize step tracking
	completed_steps.resize(total_steps)
	completed_steps.fill(false)
	print("Level started: ", level_name)

func complete_step(step_index: int):
	if step_index >= 0 and step_index < total_steps:
		if not completed_steps[step_index]:
			completed_steps[step_index] = true
			current_step += 1
			emit_signal("step_completed", step_index)
			print("Step checked: ", step_index)
			check_level_completion()

func check_level_completion():
	var all_steps_complete = true
	for step in completed_steps:
		if not step:
			all_steps_complete = false
			break
	
	if all_steps_complete:
		emit_signal("level_completed")
		print("Level Complete!")
