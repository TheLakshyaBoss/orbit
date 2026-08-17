extends KinematicBody

export var speed: float = 15.0
export var gravity: float = 24.0
export var jump_force: float = 8.5
export var mouse_sensitivity: float = 0.002

# Footstep Configuration
export var step_interval: float = 0.42
var step_timer: float = 0.0

# ADS & Recoil Configuration
export var ads_speed: float = 14.0
export var recoil_recovery_speed: float = 12.0

# Hip and ADS resting positions
var hip_pos: Vector3 = Vector3(3.293, -2.561, -2.504)
var ads_pos: Vector3 = Vector3(0.0, -1.45, -2.504)

# Recoil offsets
var target_gun_pos: Vector3 = Vector3.ZERO
var current_recoil: Vector3 = Vector3.ZERO

# Fire rate control
var fire_rate: float = 0.15
var fire_timer: float = 0.0

var velocity: Vector3 = Vector3.ZERO

# Node References
onready var head: Spatial = $Head
onready var camera: Camera = $Head/Camera
onready var flashlight: Spatial = $Head/Camera/Flashlight
onready var flashlight_audio: AudioStreamPlayer = $Head/Camera/FlashlightSound
onready var gun_anchor: Spatial = $Head/Camera/revolverAnchor
onready var shoot_audio: AudioStreamPlayer = $Head/Camera/revolverAnchor/revolverSound
onready var footstep_audio: AudioStreamPlayer = $FootstepSound
onready var interact_ray: RayCast = $Head/Camera/InteractRay

export var hover_label_path: NodePath = @"../UI/HoverLabel"
var hover_label: Label = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	gun_anchor.translation = hip_pos
	target_gun_pos = hip_pos

	# --- DIAGNOSTIC SETUP ---
	# 1. Force enable RayCast and interactions
	interact_ray.enabled = true
	interact_ray.collide_with_areas = true
	interact_ray.collide_with_bodies = true
	interact_ray.add_exception(self)
	
	# 2. Locate HoverLabel
	hover_label = get_node_or_null(hover_label_path)
	if not hover_label:
		# Fallback recursive search across the entire scene tree
		hover_label = get_tree().get_root().find_node("HoverLabel", true, false)
	
	if hover_label:
		print("[DEBUG SUCCESS] HoverLabel located at: ", hover_label.get_path())
		hover_label.visible = true
	else:
		printerr("[DEBUG ERROR] HoverLabel could NOT be found! Check your UI node name and path.")

func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sens_modifier = 0.6 if Input.is_action_pressed("aim") else 1.0
		rotate_y(-event.relative.x * mouse_sensitivity * sens_modifier)
		head.rotate_x(-event.relative.y * mouse_sensitivity * sens_modifier)
		head.rotation.x = clamp(head.rotation.x, deg2rad(-89), deg2rad(89))

	# Flashlight Toggle
	if event.is_action_pressed("flashlight") and not event.is_echo():
		flashlight.visible = not flashlight.visible
		flashlight_audio.play()

	# Cursor Capture Toggle
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
	# Interact
	if event.is_action_pressed("interact") and not event.is_echo():
		check_interaction()

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
	velocity.x = input_dir.x * speed
	velocity.z = input_dir.z * speed

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force

	velocity = move_and_slide(velocity, Vector3.UP, true)

	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if is_on_floor() and horizontal_velocity.length() > 0.5:
		step_timer -= delta
		if step_timer <= 0.0:
			play_footstep()
			step_timer = step_interval
	else:
		step_timer = 0.0

func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta

	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		shoot()

	if Input.is_action_pressed("aim"):
		target_gun_pos = ads_pos
	else:
		target_gun_pos = hip_pos

	current_recoil = current_recoil.linear_interpolate(Vector3.ZERO, recoil_recovery_speed * delta)
	var final_target = target_gun_pos + current_recoil
	gun_anchor.translation = gun_anchor.translation.linear_interpolate(final_target, ads_speed * delta)

	update_hover_label_debug()

func update_hover_label_debug() -> void:
	if not hover_label:
		return

	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if not collider:
			hover_label.text = "[DEBUG] Colliding with NULL"
			return

		var parent = collider.get_parent()
		var col_groups = collider.get_groups()
		var parent_groups = parent.get_groups() if parent else []

		var is_interactable = collider.is_in_group("interact") or (parent and parent.is_in_group("interact"))

		# Live on-screen diagnostics displayed on the label
		var debug_text = "HIT: %s\nPARENT: %s\nCOL GROUPS: %s\nPARENT GROUPS: %s\nIS_INTERACT: %s" % [
			collider.name,
			parent.name if parent else "None",
			str(col_groups),
			str(parent_groups),
			str(is_interactable)
		]

		if is_interactable:
			debug_text += "\n>> FINAL NAME: " + (parent.name if parent and parent.is_in_group("interact") else collider.name)

		hover_label.text = debug_text
	else:
		hover_label.text = "[DEBUG] RayCast NOT colliding (Length: %s)" % str(interact_ray.cast_to)

func shoot() -> void:
	fire_timer = fire_rate
	shoot_audio.pitch_scale = rand_range(0.95, 1.05)
	shoot_audio.play()
	current_recoil += Vector3(rand_range(-0.01, 0.9), 0.03, 0.9)

func play_footstep() -> void:
	footstep_audio.pitch_scale = rand_range(0.88, 1.12)
	footstep_audio.play()

func check_interaction() -> void:
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if not target:
			return
		
		print("[DEBUG INTERACT] Pressed E on: ", target.name)
		if target.has_method("interact"):
			target.interact(self)
		elif target.get_parent() and target.get_parent().has_method("interact"):
			target.get_parent().interact(self)
