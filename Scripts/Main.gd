extends Spatial

onready var fps_label: Label = $UI/FPSLabel

func _ready() -> void:
	# Enable fullscreen on launch
	OS.window_fullscreen = true

func _process(_delta: float) -> void:
	# Update FPS display each frame
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
