extends Area2D

signal tool_dropped(tool_name)

@export var valid_tools: Array[String] = []

func on_tool_dropped(tool_instance):
	if tool_instance.tool_name in valid_tools:
		print("Valid tool dropped: ", tool_instance.tool_name)
		emit_signal("tool_dropped", tool_instance.tool_name)
		return true
	else:
		print("Invalid tool: ", tool_instance.tool_name)
		return false
