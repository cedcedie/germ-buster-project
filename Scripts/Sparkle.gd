extends CPUParticles2D

func _ready():
	emitting = true
	finished.connect(func(): queue_free())
