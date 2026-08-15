extends KinematicBody

export var speed: float = 12.0
export var gravity: float = 24.0
export var jump_force: float = 8.5
export var mouse_sensitivity: float = 0.002

var velocity: Vector3 = Vector3.ZERO

onready var head: Spatial = $Head
onready var camera: Camera = $Head/Camera
onready var flashlight: Spatial = $Head/Camera/Flashlight
onready var flashlight_audio: AudioStreamPlayer = $Head/Camera/FlashlightSound

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotate body horizontally (yaw)
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Rotate head vertically (pitch)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		# Clamp vertical view angle so the camera doesn't flip
		head.rotation.x = clamp(head.rotation.x, deg2rad(-89), deg2rad(89))

	if event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		flashlight_audio.play()

	# Press Escape to release the mouse cursor
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	var input_dir: Vector3 = Vector3.ZERO

	if Input.is_action_pressed("ui_up"):
		input_dir -= transform.basis.z
	if Input.is_action_pressed("ui_down"):
		input_dir += transform.basis.z
	if Input.is_action_pressed("ui_left"):
		input_dir -= transform.basis.x
	if Input.is_action_pressed("ui_right"):
		input_dir += transform.basis.x

	input_dir = input_dir.normalized()

	# Horizontal movement
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	# Gravity & Jump
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1 # Slight downward force to keep floor contact
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force

	# Move with floor snap & slope handling
	velocity = move_and_slide(velocity, Vector3.UP, true)
